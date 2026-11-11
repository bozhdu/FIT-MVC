%% =========================================================================
% 辅助模块 2: 服务器端 ADMM 框架
% =========================================================================
function Z = Tensor_ADMM_SpatioTemporal(Y_in, Mask, lambda)
    [N, K, V] = size(Y_in);
    sX = [N, K, V];
    rho = 0.1; 
    mu = 2; 
    max_admm_iter = 5; 
    
    Z = Y_in;
    T = zeros(N, K, V);
    E = zeros(N, K, V);
    
    for i = 1:max_admm_iter
        % 1. 更新 T: 调用频域 Schatten-p 神器
        A_tensor = Z + E / rho;
        tau_thresh = lambda / rho; 
        

 
         [x_out, ~] = wshrinkObj(A_tensor(:), tau_thresh, sX, 0, 3);
        T = reshape(x_out, N, K, V);

        Z = (Y_in .* Mask + rho * T - E) ./ (Mask + rho);
        
      
        E = E + rho * (Z - T);
        rho = min(rho * mu, 1e5);
    end
end