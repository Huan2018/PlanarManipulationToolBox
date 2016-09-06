classdef PushedObject < handle
    % Class of object being pushed. 
   properties
      % Limit surface related.
      ls_coeffs
      ls_type
      % Pressure related.
      support_pts  %2*N
      pressure_weights  % N*1
      % Coefficient of contact friction between pusher and the object.
      %mu_contact
      % Shape and geometry related. 
      shape_id % unique id 
      shape_type % type for different methods of computing distance.
      shape_vertices % object coordinate frame. 2*N.
      shape_parameters % radius of circle, two axis length of ellipse, etc.
      pho % radius of gyration.
      
      % Pose related. object coordinate frame w.r.t the world frame.
      pose %3*1: [x;y;theta]
      cur_shape_vertices % shape vertices in world frame.
      
      % Configuration parameters for Sampling of wrench,twist pairs. 
      % When the user only gives pressure points and weights for constructor 
      % function, we will sample wrench and twist pairs instead. 
      % Total number of center of rotations (CORs). 
      num_cors
      % The ratio [0,1] of CORs that will be sampled on the limit surface facet. 
      r_facet 
      
   end
   methods
       function obj = PushedObject(support_pts, pressure_weights, shape_info, ls_type, ls_coeffs) 
            obj.support_pts = support_pts;
            obj.pressure_weights = pressure_weights;

            obj.shape_id = shape_info.shape_id;
            obj.shape_type = shape_info.shape_type;
            obj.pho = shape_info.pho;
            if strcmp(obj.shape_type,'polygon')
                obj.shape_vertices = shape_info.shape_vertices;
            else
                obj.shape_parameters = shape_info.shape_parameters;
            end
            if (nargin == 5)
                obj.ls_type = ls_type;
                obj.ls_coeffs = ls_coeffs;
            else
                % If no limit surface information is provided. By default, we will fit a
                % ellipsoid model for it.
                obj.SetWrenchTwistSamplingConfig(200, 0.5);
                obj.FitLSFromPressurePoints('quadratic');
            end

       end
       function [obj] = SetWrenchTwistSamplingConfig(obj, num_cors, r_facet)
           if (num_cors < 15)
                disp('More wrench-twist points would be better.')
           end
           obj.num_cors = num_cors;
           obj.r_facet = r_facet;
       end
       
       function [obj] = FitLSFromPressurePoints(obj, ls_type)
            if (nargin == 1)
                obj.ls_type = 'quadratic';
            else
                if (strcmp(ls_type, 'quadratic') || strcmp(ls_type, 'poly4'))
                    obj.ls_type = ls_type;
                else
                    disp('limit surface type not recognized %s\n', ls_type);
                end
            end
            % Generate random points. 
            num_pts = size(obj.support_pts, 2);
            num_facet_pts = ceil(obj.r_facet * (obj.num_cors / 2) / num_pts);
            num_other_pts = ceil((1 - obj.r_facet) * (obj.num_cors / 2));
            CORs = GenerateRandomCORs3(obj.support_pts, num_other_pts, num_facet_pts);
            [F, V] = GenFVPairsFromPD(obj.support_pts, obj.pressure_weights, CORs);
            % Normalize the 3rd component of wrench and twist pairs by
            % characteristic length. Here F,V are all N*3, each row is a
            % data point. Twists are additionally normalized to unit
            % vector.
            [V, F] = NormalizeForceAndVelocities(V, F, obj.pho);
            if strcmp(obj.ls_type, 'quadratic')
                [obj.ls_coeffs, xi, delta, pred_V_dir, s] = FitEllipsoidForceVelocityCVX(F', V');
            elseif strcmp(obj.ls_type, 'poly4')
                [obj.ls_coeffs, xi, delta, pred_V_dir, s] = Fit4thOrderPolyCVX(F', V');
            end
            ls_type = obj.ls_type;
            ls_coeffs = obj.ls_coeffs;
       end
           
       function [pt_closest, dist] = FindClosestPointAndDistanceWorldFrame(obj, pt)
         % Input: pt is a 2*1 column vector. 
         % Output: distance and the projected/closest point (2*1) on the object.
         dist = 0; pt_closest = [0;0];
         if strcmp(obj.shape_type, 'polygon')
             [tip_proj, dist] = projPointOnPolygon(pt', obj.cur_shape_vertices);
             pt_closest = polygonPoint(obj.cur_shape_vertices, tip_proj);
             pt_closest = pt_closest';
             
         elseif strcmp(obj.shape_type, 'circle')
             dist = norm(pt - obj.pose(1:2));
             pt_closest = obj.pose(1:2) + ...
                 obj.shape_parameters.radius * (pt - obj.pose(1:2)) / dist;
             
         elseif strcmp(obj.shape_type, 'ellipse')
         else
            fprintf('Shape meta type not supported%s\n', obj.shape_type);
         end
      end
      
      function [vec_local] = GetVectorInLocalFrame(obj, vec) 
            % Input: a column vector 2*1 in world frame.
            % Output: rotated to local frame.
            theta = obj.pose(3);
            R = [cos(theta) sin(theta); -sin(theta) cos(theta)];
            vec_local = R' * vec;
      end
      function [flag_contact] = GetRoundFingerContactInfo()
      end
          
      function [twist_local, wrench_load_local, contact_mode] = ComputeVelGivenPointRoundFingerPush(obj, ...
              pt_global, vel_global, normal_global, mu)
        % Input: 
        % contact point on the object (pt 2*1), pushing velocity (vel 2*1)
        % and outward normal (2*1, pointing from object to pusher) in world frame;  
        % mu: coefficient of friction. 
        % Note: Ensure that the point is actually in contact before using
        % this function. It does not check point on boundary.
        % Output: 
        % Body twist, friction wrench load (local frame) on the 1 level set of
        % limit surface and contact mode ('separation', 'sticking', 'leftsliding', 'rightsliding' ). 
        % Note that the third component is unnormalized,
        % i.e, F(3) is torque in NewtonMeters and V(3) is radian/second. 
        % If the velocity of pushing is breaking contact, then we return 
        % all zero 3*1 vector. 
        
        % Change vel, pt and normal to local frame first. 
        vel_local = obj.GetVectorInLocalFrame(vel_global);        
        % Compute the point of contact.
        pt_local = obj.GetVectorInLocalFrame(pt_global);
        normal_local = obj.GetVectorInLocalFrame(normal_global);
        
        [wrench_load_local, twist_local, contact_mode] = ComputeVelGivenSingleContactPtPush(vel_local, pt_local, ...
            normal_local, mu, obj.pho, obj.ls_coeffs, obj.ls_type);
        % Un-normalize the third components of F and V.
        wrench_load_local(3) = wrench_load_local(3) * obj.pho;
        twist_local(3) = twist_local(3) / obj.pho;  
        
      end
      
   end
end