
clear; clc; close all;
warning off;

addpath('functions\');
addpath('measure\');

dataset_name = '100Leaves';  
missing_rate = 0.1;        % 缺失率 (0 为无后缀完整版, 0.1, 0.3 为缺失版)


if missing_rate == 0
    suffix = ''; 
else
    suffix = sprintf('_MR%.1f', missing_rate); 
end


data_folder = fullfile('./Federated_Data/', dataset_name);


metadata_name = sprintf('%s_Server_Metadata%s.mat', dataset_name, suffix);
load(fullfile(data_folder, metadata_name)); 

% 2. 读取 Client 文件模式
client_pattern = sprintf('%s_Client_*%s.mat', dataset_name, suffix);
all_files = dir(fullfile(data_folder, client_pattern));


if missing_rate == 0
    
    valid_indices = [];
    for i = 1:length(all_files)
        if ~contains(all_files(i).name, '_MR')
            valid_indices = [valid_indices, i];
        end
    end
    client_info = all_files(valid_indices);
else

    client_info = all_files;
end

V = length(client_info); 




K = K_true;         
max_rounds = 15;    
local_epochs = 3;  

dropout_rate = 0;
LM = [1e-4, 1e-3, 1e-2, 1e-1, 1e0, 1e1, 1e2, 1e3, 1e4]; 
LB = [1e-4, 1e-3, 1e-2, 1e-1, 1e0, 1e1, 1e2, 1e3, 1e4]; 

for rp1 = 7%1:length(LM) 
    for rp2 = 5%1:length(LB) 
        beta   = LM(rp1);
        lambda = LB(rp2);
        
       % ================= 初始化部分 =================
        Z_server = zeros(N_total, K, V);
        Z_server_old = zeros(N_total, K, V);
        
        Y_old = cell(1, V);
        for v = 1:V
            Y_old{v} = zeros(N_total, K);
        end
        
        convergence_err_server = zeros(1, max_rounds);
        convergence_err_client = zeros(1, max_rounds);
        tol = 1e-4;
        
        % 通信量统计，按照32-bit浮点数计算
        bytes_per_float = 4;
        
        upload_elements = 0;
        download_elements = 0;
        
        client_upload_elements = zeros(V, 1);
        client_download_elements = zeros(V, 1);
        
        actual_rounds = max_rounds;
        
        timer_total = tic;
        
        for r = 1:max_rounds
        
            uploaded_Y = cell(1, V);
            client_err_sum = 0;
        
            active_clients = rand(1, V) >= dropout_rate;
        
            if sum(active_clients) == 0
                active_clients(randi(V)) = true;
            end
        
            % ---------------- Client-Side ----------------
            for v = 1:V
        
                if active_clients(v)
                    this_client_file = sprintf( ...
                        '%s_Client_%d%s.mat', ...
                        dataset_name, v, suffix);
        
                    client_data = load( ...
                        fullfile(data_folder, this_client_file));
        
                    % Downlink: Server -> Client
                    Z_v_cons = full( ...
                        P_cell{v}' * Z_server(:, :, v));
        
                    current_download = numel(Z_v_cons);
        
                    download_elements = ...
                        download_elements + current_download;
        
                    client_download_elements(v) = ...
                        client_download_elements(v) + current_download;
        
                    % Local optimization
                    [uploaded_Y{v}, ~, ~] = Local_Optimization( ...
                        client_data.X, ...
                        Z_v_cons, ...
                        K, ...
                        local_epochs, ...
                        beta);
        
                    % Uplink: Client -> Server
                    current_upload = numel(uploaded_Y{v});
        
                    upload_elements = ...
                        upload_elements + current_upload;
        
                    client_upload_elements(v) = ...
                        client_upload_elements(v) + current_upload;
        
                    if r > 1
                        diff_norm = norm( ...
                            uploaded_Y{v} - Y_old{v}, 'fro');
        
                        old_norm = norm(Y_old{v}, 'fro');
        
                        client_err_sum = ...
                            client_err_sum + ...
                            diff_norm / (old_norm + 1e-8);
                    end
        
                    Y_old{v} = uploaded_Y{v};
        
                else
                    uploaded_Y{v} = Y_old{v};
                end
            end
        
            if r == 1
                convergence_err_client(r) = 1;
            else
                convergence_err_client(r) = ...
                    client_err_sum / sum(active_clients);
            end
        
            % ---------------- Server-Side ----------------
            Y_incomplete = zeros(N_total, K, V);
            Mask = zeros(N_total, K, V);
        
            for v = 1:V
                if active_clients(v)
                    Y_incomplete(:, :, v) = ...
                        full(P_cell{v} * uploaded_Y{v});
        
                    Mask(:, :, v) = ...
                        full(P_cell{v} * ...
                        ones(size(uploaded_Y{v})));
                else
                    Y_incomplete(:, :, v) = 0;
                    Mask(:, :, v) = 0;
                end
            end
        
            Z_server = Tensor_ADMM_SpatioTemporal( ...
                Y_incomplete, Mask, lambda);
        
            if r == 1
                convergence_err_server(r) = 1;
            else
                diff_norm_Z = norm( ...
                    Z_server(:) - Z_server_old(:));
        
                old_norm_Z = norm(Z_server_old(:));
        
                convergence_err_server(r) = ...
                    diff_norm_Z / (old_norm_Z + 1e-8);
        
                if convergence_err_server(r) < tol
                    actual_rounds = r;
                    break;
                end
            end
        
            Z_server_old = Z_server;
        end
        
        time = toc(timer_total);
        
        % ================= 通信量结果 =================
        %{
        upload_MB = ...
            upload_elements * bytes_per_float / 1024^2;
        
        download_MB = ...
            download_elements * bytes_per_float / 1024^2;
        
        total_communication_MB = upload_MB + download_MB;
        
        client_upload_MB = ...
            client_upload_elements * bytes_per_float / 1024^2;
        
        client_download_MB = ...
            client_download_elements * bytes_per_float / 1024^2;
        
        client_total_MB = client_upload_MB + client_download_MB;
        
        fprintf('\nCommunication rounds: %d\n', actual_rounds);
        fprintf('Upload communication: %.4f MB\n', upload_MB);
        fprintf('Download communication: %.4f MB\n', download_MB);
        fprintf('Total communication: %.4f MB\n', ...
            total_communication_MB);
        
        communication_table = table( ...
            (1:V)', ...
            client_upload_MB, ...
            client_download_MB, ...
            client_total_MB, ...
            'VariableNames', { ...
                'Client', ...
                'Upload_MB', ...
                'Download_MB', ...
                'Total_MB'});
        
        disp(communication_table);
        %}
        % ---------------- 【画双线收敛图】 ----------------
        %figure;
        % plot(1:max_rounds, convergence_err_server, '-o', 'LineWidth', 2, 'MarkerSize', 6, 'DisplayName', 'Server Z');
        %hold on;
        %plot(1:max_rounds, convergence_err_client, '-s', 'LineWidth', 2, 'MarkerSize', 6, 'DisplayName', 'Client Y');
        %xlabel('Global Communication Rounds');
        %ylabel('Relative Error (F-norm)');
        %title(sprintf('Convergence on %s (Missing Rate: %.1f)', dataset_name, missing_rate));
        %legend('show');
        %grid on;
        
            Final_Prob = mean(Z_server, 3);
        
        
        
            [~, res_all] = myNMIACCwithmean(Final_Prob,Y_full,K); %[ACC nmi Purity Fscore Precision Recall AR Entropy];
          
            % [ACC, NMI, Purity, F-score, Precision, Recall, AR, Entropy]
        
            cols = [1, 2, 3, 4, 7];
        
            res_mean = mean(res_all(:, cols), 1);
            res_std  = std(res_all(:, cols), 0, 1);
        
            metric_names = {'ACC', 'NMI', 'Purity', 'F-score', 'AR'};
            
            for i = 1:length(metric_names)
                fprintf('%-8s: %.4f +/- %.4f\n', ...
                    metric_names{i}, res_mean(i), res_std(i));
            end
            disp(time);

        end
end