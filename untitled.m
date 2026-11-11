clear; clc; close all;

% 1. 你的真实数据
dropout_rates = [0, 0.1, 0.2, 0.3, 0.4, 0.5];
acc_data = [
    97.73, 98.46, 98.46, 99.03, 99.03, 99.03;  % HW
    81.14, 81.14, 82.17, 82.17, 82.17, 75.90;  % ORL
    53.01, 52.97, 52.97, 53.98, 57.15, 52.47;  % proteinFold
    80.43, 80.14, 80.14, 75.85, 75.85, 75.85;  % BDGP
    81.21, 81.21, 81.21, 81.21, 72.04, 72.04;  % 100Leaves
    88.78, 74.53, 74.53, 74.53, 74.53, 74.53;  % DryBean
    54.98, 39.54, 37.08, 37.08, 37.08, 37.08   % CCV
];

datasets = {'HW', 'ORL', 'proteinFold', 'BDGP', '100Leaves', 'DryBean', 'CCV'};
num_datasets = length(datasets);

% 2. 计算相对性能保留率 (Relative Retention)
relative_acc = (acc_data ./ acc_data(:, 1)) * 100;

% 3. 绘图设置
figure('Position', [100, 100, 750, 550], 'Color', 'w');
hold on;

% 提取高对比度的颜色和标记
colors = lines(num_datasets); 
markers = {'o', 's', '^', 'd', 'v', 'p', 'h'};

% 循环绘制每一条线
h = zeros(1, num_datasets);
for i = 1:num_datasets
    h(i) = plot(dropout_rates, relative_acc(i, :), ...
        'LineStyle', '-', ...
        'LineWidth', 2.5, ...               
        'Color', colors(i,:), ...
        'Marker', markers{i}, ...
        'MarkerSize', 8, ...
        'MarkerFaceColor', colors(i,:), ... 
        'MarkerEdgeColor', 'w');            
end

% 4. 坐标轴与排版精修
set(gca, 'FontSize', 12, 'FontName', 'Times New Roman', 'LineWidth', 1.2);
xlabel('Client Dropout Rate', 'FontSize', 14, 'FontWeight', 'bold');
ylabel('Relative ACC Retention (%)', 'FontSize', 14, 'FontWeight', 'bold');
title('Robustness to Client Dropouts ', 'FontSize', 16, 'FontWeight', 'bold');

% 【核心修改】：根据你的真实数据，放宽 Y 轴范围
xlim([0, 0.5]);
ylim([60, 110]); 
xticks(dropout_rates);
yticks(60:10:110);

% 画一条 100% 的参考虚线，凸显 proteinFold 的“逆势上涨”
plot([-0.1, 0.6], [100, 100], 'k--', 'LineWidth', 1.5, 'HandleVisibility', 'off');

% 添加网格线
grid on;
set(gca, 'GridLineStyle', '--', 'GridAlpha', 0.3);

% 将图例放在左下角（因为你的数据在右侧普遍下降，左下角比较空）
lgd = legend(h, datasets, 'Location', 'southwest', 'NumColumns', 2);
set(lgd, 'FontSize', 11, 'FontName', 'Times New Roman', 'Box', 'off');

hold off;