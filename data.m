%% 读取真实的联邦多视图数据集并生成物理隔离文件
clear; clc;

% =========================================================================
% 1. 配置参数 (根据你的实际情况修改)
% =========================================================================
% 你的原始数据集文件路径 (假设文件里包含特征矩阵 X 和真实标签 Y/gt)
dataset_filepath = './data/stl10.mat'; % <--- 替换为你的真实数据集名称 (如 100Leaves.mat)

missing_rate = 0;          % 缺失率：0.3 表示每个机构随机丢失 30% 的样本
output_dir = './Federated_Data/'; 

if ~exist(output_dir, 'dir')
    mkdir(output_dir); 
end

fprintf('开始读取原始数据集: %s ...\n', dataset_filepath);

% =========================================================================
% 2. 自动加载与格式适配
% =========================================================================
try
    rawData = load(dataset_filepath);
catch
    error('无法读取文件 %s，请确保该数据集在当前文件夹中！', dataset_filepath);
end

% 智能提取特征 X 和标签 Y (兼容不同的命名习惯)
if isfield(rawData, 'X')
    X_full = rawData.X;
elseif isfield(rawData, 'fea')
    X_full = rawData.fea;
else
    error('在数据集中找不到特征变量 (通常命名为 X 或 data)');
end

if isfield(rawData, 'Y')
    Y_full = rawData.Y;
elseif isfield(rawData, 'gnd')
    Y_full = rawData.gnd;
elseif isfield(rawData, 'truth')
    Y_full = rawData.truth;
elseif isfield(rawData, 'truelabel')
    Y_full = rawData.truelabel;
else
    error('在数据集中找不到标签变量 (通常命名为 Y, gt, label)');
end

% 确保标签是列向量，并获取全局参数
Y_full = double(Y_full(:)); 
N_total = length(Y_full);
K_true = length(unique(Y_full));
V = length(X_full);

fprintf('数据集加载成功！\n');
fprintf('  - 视图总数 V: %d\n', V);
fprintf('  - 全局样本数 N: %d\n', N_total);
fprintf('  - 真实类别数 K: %d\n', K_true);
rng(12, 'twister')
% =========================================================================
% 3. 核心修复：特征单位范数归一化 (防止距离爆炸导致标签全1)
% =========================================================================
fprintf('\n执行特征 L2 归一化...\n');
for v = 1:V
    X_v = double(X_full{v});
    
    % 检查维度方向 (如果是 N x d，则转置为 d x N)
    if size(X_v, 2) ~= N_total && size(X_v, 1) == N_total
        X_v = X_v'; 
    end
    
    % L2 归一化：将每个样本投影到单位超球面上
    X_norm = bsxfun(@rdivide, X_v, sqrt(sum(X_v.^2, 1) + 1e-12));
    X_full{v} = X_norm;
    
    fprintf('  - 视图 %d: 特征维度 %d\n', v, size(X_norm, 1));
end

% =========================================================================
% 4. 模拟纵向联邦分布与样本不对齐
% =========================================================================
fprintf('\n开始切分数据并生成联邦客户端文件 (缺失率 %.1f%%)...\n', missing_rate * 100);
P_cell = cell(1, V);

for v = 1:V
    % 随机掩码：决定该客户端拥有哪些样本
    keep_mask = rand(1, N_total) > missing_rate;
    keep_idx = find(keep_mask); 
    N_v = length(keep_idx);
    
    % 提取本地私有数据
    X = X_full{v}(:, keep_idx);
    local_sample_ids = keep_idx;
    d_v = size(X, 1);
    
    % 构造全局投影矩阵 P (N_total x N_v)
    % P 矩阵用于服务器端将本地标签对齐到全局张量的正确位置
    P = sparse(keep_idx, 1:N_v, ones(1, N_v), N_total, N_v);
    P_cell{v} = P;
    
    % 保存客户端文件
    client_file = fullfile(output_dir, sprintf('/stl10_Client_%d.mat', v));
    save(client_file, 'X', 'local_sample_ids', 'd_v', 'N_v');
    fprintf('  -> Client_%d.mat 保存成功 (持有 %d 个样本).\n', v, N_v);
end

% =========================================================================
% 5. 保存服务器元数据
% =========================================================================
server_file = fullfile(output_dir, '/stl10_Server_Metadata.mat');
save(server_file, 'P_cell', 'N_total', 'V', 'K_true', 'Y_full');
fprintf('\n✅ 预处理全部完成！可以运行主联邦算法了。\n');