%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%EKF tracking 2D with P model and euclidean distance measurements%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear all;
close all;
clc;
%% load the trajectory
%file = load('hard2.mat');
file = load('easy2.mat');
X = file.X;
%% normalization for a room of dimensions 30x10 m

N = size(X,1);
%% define the positions of the sensors
radius = 6;% this is how far the sensor can work 
s = [7.5,3.5;   ...
     15,5;      ...
     20,3.5;    ...
     20,7.5;    ...
     7.5,7.5;   ...
     10,10;     ...
     10,2;      ...
     17.5,10;   ...
     17.5,2;    ...
    ];

% define polling query of sensors
dt = 5;
% number of sensors
p = size(s,1);
% dimension of the states : 2D motion x,y
n = 2;

count = 0;
for t=dt+1:dt:N
    v(t) =  sqrt((X(t,1)-X(t-dt,1))^2 + (X(t,2)-X(t-dt,2))^2 )/dt;
    delta_v(t) = abs(v(t)-v(t-dt));
    count = count+1;
end

v_mean = sum(v)/count;
delta_v_mean = sum(delta_v)/count;

%% plot the trajectory and sensors position
figure;
plot(X(:,1),X(:,2));
hold on;
plot(s(:,1),s(:,2), 'x');
t = linspace(0,2*pi);
for j=1:size(s,1)
    plot(radius*cos(t)+s(j,1),radius*sin(t)+s(j,2),'--');
end




%% define the matrix of motion equation
%F = [1,0 ; 0,1]; % brownian motion

%% process covariance
%Ex = eye(n);


% NEW MODEL
%% process covariance : velocity acceleration model
accel_noise_mag = .001; % process noise: the variability in how fast the target is speeding up (stdv of acceleration: meters/sec^2)
accel_noise_mag =(delta_v_mean)^2 / dt;
% Ex = [  dt^4/4 0 dt^3/2 0; ...
%         0 dt^4/4 0 dt^3/2; ...
%         dt^3/2 0 dt^2 0; ...
%         0 dt^3/2 0 dt^2] .* accel_noise_mag^2; % Ex convert the process noise (stdv) into covariance matrix

Ex = [  dt^3/3 0 dt^2/2 0; ...
        0 dt^3/3 0 dt^2/2; ...
        dt^2/2 0 dt 0; ...
        0 dt^2/2 0 dt] .* accel_noise_mag; % Ex convert the process noise (stdv) into covariance matrix
    
%% [state transition (state + velocity)] + [input control (acceleration)]
F = [1 0 dt 0; 0 1 0 dt; 0 0 1 0; 0 0 0 1]; %state update matrice
% G = [(dt^2/2) 0 ; 0 (dt^2/2); dt 0 ; 0 dt];
% u = [1;1]*0.0005; % define acceleration magnitude
%u = [0;0];



%% Initialization
%x_hat = [X(1,1); X(1,2)];
x_hat = [X(1,1); X(1,2); 0; 0 ];
P = Ex; % estimate of initial position variance (covariance matrix)
prediction = x_hat';

%% Simulate noised measurements
distances = zeros(size(s,1),N);
noised_distances = zeros(size(s,1),N);
for t=1:N
     for k=1:size(s,1)
         distances(k,t) = sqrt((X(t,1)-s(k,1)).^2 + (X(t,2)-s(k,2)).^2);
         if distances(k,t) > radius
             distances(k,t) = 0;
         else
             noised_distances(k,t) = awgn(distances(k,t),10);
         end
         
     end
end

%% output covariance : each sensor has its own uncertainty and it's uncorrelated with the others
var_z =0.1;
Ez = eye(p)*var_z;

number_est = 1;
dist_max = 0;
%% Kalman filter
for t=1:dt:N
    
    z = noised_distances(:,t);
    h = zeros(size(s,1),1);
    for k=1:size(s,1)
        if z(k) ~=0
            h(k) = sqrt((x_hat(1) - s(k,1)).^2 + (x_hat(2) - s(k,2)).^2);
        end
    end
    
    %% building H matrix
    H = [];
    active_sensors = 0;
    for i=1:size(z,1)
        if z(i) ~= 0 % si linearizza e si calcola nella predizione precedente
            
            dh_dx = (x_hat(1)-s(i,1))/sqrt((x_hat(1)-s(i,1))^2 + (x_hat(2)-s(i,2))^2);
            dh_dy = (x_hat(2)-s(i,2))/sqrt((x_hat(1)-s(i,1))^2 + (x_hat(2)-s(i,2))^2);
            %H = [H;  dh_dx dh_dy]; 
            H = [H;  dh_dx dh_dy 0 0 ];
            active_sensors = active_sensors + 1;
        else
            %H = [H; 0 0 ];
            H = [H; 0 0 0 0];
        end
    end
    
    if active_sensors<2
        disp('Attenzione sensori rilevati inferiori a 2');
    end
    %% prediction step
    
    % project the state ahead
    x_hat = F * x_hat;
    %x_hat =  F * x_hat + G*u;
    % project the covariance ahead
    P_hat = F*P*F' + Ex;
    
    %% correction step
    
    % compute the kalman gain
    K = P_hat*H' * inv(H*P_hat*H' + Ez); 
    
    % update the state estimate with measurement z(t)
    x_hat = x_hat + K*(z-h);
    % update the error covariance
    %P = (eye(2)-K*H)*P_hat;
    P = (eye(4)-K*H)*P_hat;
    
    
    prediction = [prediction; x_hat'];
    
   %% compute distance error 
    
    x_err(number_est) = X(t,1) - x_hat(1);
    y_err(number_est) = X(t,2) - x_hat(2);
    
    dist(number_est) = sqrt(x_err(number_est).^2 + y_err(number_est).^2);
    
    if dist(number_est) > dist_max
        dist_max = dist(number_est);
        pos_dist_max = number_est;
    end
    
    number_est = number_est+1;
    
end

dist_err = sum(dist) / number_est;
RMSE_x = sqrt(sum(x_err.^2)/number_est);
RMSE_y = sqrt(sum(y_err.^2)/number_est);
RMSE_net = sqrt(RMSE_x.^2 + RMSE_y.^2);


disp(['Distance Error Avg: ',num2str(dist_err)]);
disp(['Distance Error Max : ',num2str(dist_max)]);
disp(['RMSE_x : ',num2str(RMSE_x)]);
disp(['RMSE_y : ',num2str(RMSE_y)]);
disp(['RMSE_net : ',num2str(RMSE_net)]);

plot(prediction(:,1),prediction(:,2),'Color','Green');

