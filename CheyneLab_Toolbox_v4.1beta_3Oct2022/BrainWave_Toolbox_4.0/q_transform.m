function y = q_transform(x, Q)

    % D. Cheyne, May 2014
    % from MaxFilter manual
    % this is a guess...
    %
    % transformation of point by the six quaternions
    % defined by vector Q from the MaxMove output 
    % x is point in device coordinates, 
    % should return y = point in head coords?
        
    q1 = Q(1);
    q2 = Q(2);
    q3 = Q(3);
    q4 = Q(4);
    q5 = Q(5);
    q6 = Q(6);

    q0 = sqrt(1 - q1^2 + q2^2 + q3^2);

    R = zeros(3,3);
    R(1,:) = [q0^2+q1^2-q2^2+q3^2 2*(q1*q2-q0*q3) 2*(q1*q3+q0*q2)];
    R(2,:) = [2*(q1*q2+q0*q3) q0^2+q2^2-q1^2-q3^2  2*(q2*q3-q0*q1)]; 
    R(3,:) = [2*(q1*q3-q0*q2) 2*(q2*q3+q0*q1) q0^2+q3^2-q1^2-q2^2];

    T = [q4 q5 q6]';

    y = R*x + T;


end
