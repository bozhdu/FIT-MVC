
function [Y, Dist,Phi] = Local_Optimization(X, Z_cons, K, epochs, beta)
    [~, N_v] = size(X);
    % 初始化锚点: 在本地样本池中随机抽取真实数据
    rng(12, 'twister')
    [~, C_init] = kmeans(X', K, 'MaxIter', 10, 'Replicates', 1);
  
    C = C_init'; 
    
    for iter = 1:epochs
        %Y step
        Dist = pdist2(X', C').^2;
        
        sigma = mean(Dist(:)) * 0.1 + 1e-9; 
        Omega = exp(-Dist / sigma);
        Phi = 1 - Omega;
        
        
        Y = (Omega + beta * Z_cons) ./ (2*Phi + beta + 1) ;
        %Y = (beta * Z_cons) ./ (2*Phi + beta) ;
        Y = bsxfun(@rdivide, Y, sum(Y, 2) + 1e-12); % Simplex 投影
     
        %  C step
        for k = 1:K
            % 必须乘以 Omega(:, k) 才能真正抵抗 Outliers 噪声！
            W_local = (Y(:, k).^2) .* Omega(:, k); 
            if sum(W_local) > 1e-6
                C(:, k) = (X * W_local) / sum(W_local);
            end
        end
    end
end