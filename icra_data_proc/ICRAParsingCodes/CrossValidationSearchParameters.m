%Input:
%F, V: N*3 row-wise data matrix.
%method: string indicating specific training methods.
function [para] = CrossValidationSearchParameters(F_train, V_train, F_val, V_val, options)
flag_plot = 0;
% weight for velocity matching is fixed at 1.
w_vel = [1,2,4];
% regularization of parameters w.r.t velocity matching.
% More regularization for real robot exp.
%w_reg = [0.1, 2, 8, 16];
w_reg = [0.25, 0.5, 1];
w_force = [0.1, 0.5, 1, 2, 4];

% Parameters for mcube data. (smaller range for speed).
w_vel = [1, 4];
w_reg = [0.1, 0.25, 1];
w_force = [0.1, 1, 4];


method = options.method;

best_err = 1e+9;
best_dev_angle = 1e+9;
best_w_force = -1;
best_w_reg = -1;
best_w_vel = -1;
train_err_record = 1e+9;
train_dev_angle_record = 1e+9;

if ~strcmp(method, 'gp')
    flag_dir = options.flag_dir;
    flag_convex = options.flag_convex;
    % force matching relative to velocity.
    if (flag_dir)
        w_force = [0];
    else
        % for real robot data.
        %w_force = [0.1, 0.5, 1, 4];
        %w_force = [0.1, 1, 4, 8];
        %w_force = [0.1, 0.5, 1, 2, 4, 8];
        %w_force = [0.5, 1, 2, 4, 8];
    end
    for ind_f = 1:length(w_force)
        for ind_v = 1:length(w_vel)
            for ind_r = 1:length(w_reg)
                option_train.weight_regularization = w_reg(ind_r);
                option_train.weight_twist = w_vel(ind_v);
                option_train.weight_wrench = w_force(ind_f);
                option_train.flag_convex = 1; option_train.flag_plot = 0;
               if (strcmp(method, 'poly4'))   
                    %[coeffs, xi, delta, pred_v_train, s] = ...
                    %   Fit4thOrderPolyCVX(wrenches_train', twists_train', w_vel(ind_r), w_force(ind_f), flag_convex, flag_plot);
                   [coeffs, xi, delta, pred_v_train, s] = ...
                       Fit4thOrderPolyCVXOptions(F_train', V_train', option_train);
                   % Evaluate on validation set.
                   [err ,dev_angle] = EvaluatePoly4Predictor(F_val, V_val, coeffs);
                   [train_err, train_dev_angle] = EvaluatePoly4Predictor(F_train, V_train, coeffs);
                   fprintf('poly4: w_force:%f, w_vel:%f, w_reg:%f, dev_angle_train:%f, dev_angle_val:%f\n', w_force(ind_f), w_vel(ind_v), w_reg(ind_r), train_dev_angle, dev_angle);

               elseif (strcmp(method, 'quadratic'))
                   %[coeffs, xi_elip, delta_elip, pred_v_lr_train, s_lr] = ...
                   %    FitEllipsoidForceVelocityCVX(wrenches_train', twists_train',  w_vel(ind_v), w_force(ind_f),  flag_convex, flag_plot);
                  [coeffs, xi_elip, delta_elip, pred_v_lr_train, s_lr] = ...
                       FitEllipsoidForceVelocityCVXOptions(F_train', V_train',  option_train);
                   [err, dev_angle] = EvaluateLinearPredictor(F_val, V_val, coeffs);
                   [train_err, train_dev_angle] = EvaluateLinearPredictor(F_train, V_train, coeffs);
                   fprintf('quadratic: w_force:%f, w_vel:%f, w_reg:%f, dev_angle_train:%f, dev_angle_val:%f\n', w_force(ind_f), w_vel(ind_v), w_reg(ind_r), train_dev_angle, dev_angle);
               end

                   % Update the best so far.
                   if (best_dev_angle > dev_angle) 
                        best_err = err;
                        best_dev_angle = dev_angle;
                        train_err_record = train_err;
                        train_dev_angle_record = train_dev_angle;
                        best_w_force = w_force(ind_f);
                        best_w_vel  = w_vel(ind_v);
                        best_w_reg = w_reg(ind_r);
                        best_coeffs = coeffs;
                   end
            end
        end
    end
    para.coeffs = best_coeffs;
    para.w_force = best_w_force;
    para.w_reg = best_w_reg;
    para.w_vel = best_w_vel;
    para.err = best_err;
    para.dev_angle = best_dev_angle;
    para.train_err_record = train_err_record;
    para.train_dev_angle_record = train_dev_angle_record;
    % store validation range search.
    para.w_force_range = w_force;
    para.w_reg_range = w_reg;
    para.w_vel_range = w_vel;
else
% GP method.
    F_train_dir = UnitNormalize(F_train);
    F_train_dir_gp = [F_train_dir; -F_train_dir];
    V_train_dir_gp = [V_train; -V_train];
    F_val_dir = UnitNormalize(F_val);
    sn = [0.05, 0.1, 0.2, 0.4, 0.8, 1.6, 3.2];
    l = [0.05, 0.1, 0.2, 0.4, 0.8, 1.6, 3.2];
    for ind_sn = 1:length(sn)
        for ind_l = 1:length(l)
            prior_gp.sn = sn(ind_sn);
            prior_gp.l = l(ind_l);
            [hyp, err_angle_train, err_angle_val] = GP_Fitting(F_train_dir_gp, V_train_dir_gp, F_val_dir, V_val, prior_gp);
            if (best_dev_angle > err_angle_val)
                best_dev_angle = err_angle_val;
                para.dev_angle = best_dev_angle;
                para.train_dev_angle_record = err_angle_train;
                para.gp_hyp = hyp;
                para.coeffs = prior_gp;
            end
            %fprintf('gp: sn:%f, l:%f, dev_angle_train:%f, dev_angle_val:%f\n', prior_gp.sn, prior_gp.l, err_angle_train, err_angle_val);
        end
    end
end


end

