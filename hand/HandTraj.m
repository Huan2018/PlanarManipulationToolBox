classdef HandTraj < handle
    % Class of a hand trajectory.
    properties
        % configurations of hand over t in global frame. d*N; 
        % We follow the convention that the first 3 elements of q is the
        % local frame (x,y,theta) w.r.t the global frame.
        q 
        qdot % (optional) config velocities over t in global frame. d*N;
        t % time. length = N. 
        interp_mode % interpolation mode. 
        traj_interp % trajectory interpolator. 
        flag_angle_interp % flag whether to map to [cos(theta), sin(theta)] space for angle interpolation.
    end
        
    methods
        % Specify properties through opts.
        function [obj] = HandTraj(opts)
            if ~ (isfield(opts, 'q') && isfield(opts,'t'))
                error('The configurations and time need to be specified');
            end
            obj.q = opts.q;
            obj.t = opts.t;
            if ~ (isfield(opts, 'interp_mode'))
                display('The interpolation method is not defined. Use default spline method.');
                obj.interp_mode = 'spline';
            else
                obj.interp_mode = opts.interp_mode;
            end
            if (strcmp(obj.interp_mode, 'pchipd')) && ~(isfield(opts,'qdot'))
                error('The velocities need to be specified for pchipd method');
            end
            if isfield(opts,'qdot')
                obj.qdot = opts.qdot;
            end
%             if isfield(opts, 'flag_angle_interp')
%                 obj.flag_angle_interp = opts.flag_angle_interp;
%             else
%                 obj.flag_angle_interp = 0;
%             end
            obj.GenerateInterpolation();
        end
        
        function [obj] = GenerateInterpolation(obj)
            % Create the trajectory interpolator in hand configuration
            % space. 
            obj.traj_interp = TrajectoryInterp();
            obj.traj_interp.SetInterpMode(obj.interp_mode);
            if strcmp(obj.interp_mode, 'pchipd')
                obj.traj_interp.SetPositionVelocityOverTime(obj.t, obj.q, obj.qdot);
            else
%                 if obj.flag_angle_interp
%                     q_interp_pts = [obj.q(1:2,:); obj.AnglesToPointsOnCircle(obj.q(3,:))];
%                 else
%                     q_interp_pts = obj.q;
%                 end
%                 obj.traj_interp.SetPositionOverTime(obj.t, q_interp_pts);
              obj.q(3,:) = obj.SmoothAngleWrapAround(obj.q(3,:));
              obj.traj_interp.SetPositionOverTime(obj.t, obj.q);  
            end 
            % Generate interpolation coefficients.
            obj.traj_interp.GenerateInterpPolynomial();
        end
        
        % Get the configuration of the hand at time t. 
        % Output column vector.
        function [qt] = GetHandConfiguration(obj, t)
            qt = obj.traj_interp.GetPosition(t)';
        end
        % Get the configuration dot of the hand at time t. 
        function [qdot] = GetHandConfigurationDot(obj, t)
            qdot = obj.traj_interp.GetVelocity(t)';
        end
        % Deal with angle wrap around.
        function [smoothed_angles] = SmoothAngleWrapAround(obj, angles)
            % angles is a row vector.
            smoothed_angles = mod(angles, 2*pi);
            add_values = [-2*pi;0;2*pi];
            for i = 2:length(smoothed_angles)
                new_values = bsxfun(@plus, add_values, smoothed_angles(i));
                diff_values = abs(bsxfun(@minus, new_values, smoothed_angles(i-1)));
                [~,ind] = min(diff_values);
                smoothed_angles(i) = new_values(ind);
            end
        end
%         function [q_angles] = AnglesToPointsOnCircle(obj, angles)
%             q_angles = [cos(angles);sin(angles)];
%         end
%         function [angles] = PointsOnCircleToAngles(obj, q_angles)
%             angles = atan2(q_angles(2,:), q_angles(1,:));
%         end
    end
    
end

