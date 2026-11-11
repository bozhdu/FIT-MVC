
% 广义 p 范数软阈值算子 (Generalized Soft-Thresholding)
function x = solve_Lp_w(y, lambda, p)
    if p == 1
        x = max(y - lambda, 0); % 标准核范数
    else
        % p < 1 时的 GST 快速近似求解
        J = 2; 
        tau = (2 * lambda * (1 - p))^(1 / (2 - p)) + p * lambda * (2 * (1 - p) * lambda)^((p - 1) / (2 - p));
        x = zeros(size(y));
        idx = find(abs(y) > tau);
        if ~isempty(idx)
            y_idx = y(idx);
            x_idx = abs(y_idx);
            for iter = 1:J
                x_idx = abs(y_idx) - lambda * p * (x_idx).^(p - 1);
            end
            x(idx) = sign(y_idx) .* x_idx;
        end
    end
end