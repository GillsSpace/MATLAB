%% Data Preparation
% Define and shuffle input ranges
x = -10:0.0001:10; % Reduced step size for visualization
y = -10:0.0001:10;
x = x(randperm(length(x)));
y = y(randperm(length(y)));

% Compute outputs
z_values = (x.^2) .* y + 1; % Function output (continuous)

% Preallocate training/testing indices
num_data = numel(x);
num_train = floor(0.8 * num_data);
train_idx = 1:num_train;
test_idx = num_train+1:num_data;

% Split into training/testing data
x_train = x(train_idx);
y_train = y(train_idx);
z_train = z_values(train_idx);

x_test = x(test_idx);
y_test = y(test_idx);
z_test = z_values(test_idx);

%% Neural Network Definition
NN = dlnetwork([
    featureInputLayer(2, "Name", "InputLayer") % Two input features: x and y
    fullyConnectedLayer(32, "Name", "HiddenLayer1", "WeightsInitializer", "he")
    reluLayer("Name", "ReLU")
    dropoutLayer(0.2, "Name", "Dropout")
    fullyConnectedLayer(1, "Name", "OutputLayer", "WeightsInitializer", "glorot") % Single output (for regression)
]);

%% Training Configuration
loss_function = 'mse'; % Use mean squared error for regression
training_options = trainingOptions("adam", ...
    LearnRateSchedule = "polynomial", ...
    MaxEpochs = 30, ...
    MiniBatchSize = 128, ...
    ExecutionEnvironment = "cpu", ...
    Verbose = true, ...
    Plots = "training-progress");

%% Train and Test the Neural Network
NN = trainnet([x_train', y_train'], z_train', NN, loss_function, training_options);
Results = testnet(NN, [x_test', y_test'], z_test', loss_function);

%% Visualization: Generate 3D Plots
% Create a grid for x and y
[x_grid, y_grid] = meshgrid(-10:0.5:10, -10:0.5:10);
grid_points = [x_grid(:), y_grid(:)]'; % Transpose to make it 2-by-N

% Predict using the neural network
predictions = predict(NN, dlarray(grid_points, 'CB')); % Use dlarray for dlnetwork

% Compute original function output for comparison
z_orig = (x_grid.^2) .* y_grid + 1; % Original function

% Reshape predictions for plotting
z_pred = reshape(extractdata(predictions), size(x_grid));

% Plot original function
figure;
subplot(1, 2, 1);
surf(x_grid, y_grid, z_orig);
title('Original Function Output (z = x * y + 1)');
xlabel('x');
ylabel('y');
zlabel('z');
colormap('jet');
colorbar;

% Plot neural network predictions
subplot(1, 2, 2);
surf(x_grid, y_grid, z_pred); % Plot neural network approximation
title('Neural Network Approximation');
xlabel('x');
ylabel('y');
zlabel('Approximated z');
colormap('jet');
colorbar;
