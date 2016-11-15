fl_poly4 = dir('*poly4*');
fl_quad = dir('*quadratic*');
sum_disp_diff_poly4 = 0;
sum_angle_diff_poly4 = 0;
sum_disp_diff_quad = 0;
sum_angle_diff_quad = 0;
sum_angle_change_gt = 0;
sum_transnorm_gt = 0;
for i = 1:1:length(fl_poly4)
    load(fl_poly4(i).name);
    sum_disp_diff_poly4 = sum_disp_diff_poly4 + avg_diff_disp;
    sum_angle_diff_poly4 = sum_angle_diff_poly4 + avg_diff_angle;
    %sum_angle_change_gt = sum_angle_change_gt + avg_angle_change_gt;
    %sum_transnorm_gt = sum_transnorm_gt + avg_disp_change_norm_gt;
end
avg_disp_diff_poly4 = sum_disp_diff_poly4 / length(fl_poly4)
avg_angle_diff_poly4 = sum_angle_diff_poly4 * (180/pi) / length(fl_poly4)
avg_angle_change_gt = sum_angle_change_gt * (180/pi) / length(fl_poly4)
avg_transnorm_change_gt = sum_transnorm_gt / length(fl_poly4)

for i = 1:1:length(fl_quad)
    load(fl_quad(i).name);
    sum_disp_diff_quad = sum_disp_diff_quad + avg_diff_disp;
    sum_angle_diff_quad = sum_angle_diff_quad + avg_diff_angle;
end
avg_disp_diff_quad = sum_disp_diff_quad / length(fl_quad)
avg_angle_diff_quad = sum_angle_diff_quad * (180/pi) / length(fl_quad)