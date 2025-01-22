%% Data Preparation
% Define and shuffle input ranges
x = -10:0.0001:10;
y = -10:0.0001:10;
x = x(randperm(length(x)));
y = y(randperm(length(y)));

% Compute outputs and classify
z_values = x .* y + 1; % Inline function for performance
z_classes = z_values > 0;
z_onehot = double([z_classes; ~z_classes]');

% Preallocate training/testing indices
num_data = numel(x);
num_train = floor(0.8 * num_data);
train_idx = 1:num_train;
test_idx = num_train+1:num_data;

% Split into training/testing data
x_train = x(train_idx);
y_train = y(train_idx);
z_train = z_onehot(train_idx, :);

x_test = x(test_idx);
y_test = y(test_idx);
z_test = z_onehot(test_idx, :);

%% Neural Network Definition
NN = dlnetwork([
    featureInputLayer(2, "Name", "InputLayer")
    fullyConnectedLayer(32, "Name", "HiddenLayer1", "WeightsInitializer", "he")
    reluLayer("Name", "ReLU")
    dropoutLayer(0.2, "Name", "Dropout")
    fullyConnectedLayer(2, "Name", "OutputLayer", "WeightsInitializer", "glorot")
    softmaxLayer("Name", "Softmax")
]);

%% Training Configuration
training_options = trainingOptions("adam", ...
    LearnRateSchedule = "polynomial", ...
    MaxEpochs = 5, ...
    MiniBatchSize = 128, ...
    ExecutionEnvironment = "cpu", ...
    Verbose = true, ...
    Plots = "training-progress");

%% Train and Test the Neural Network
NN = trainnet([x_train', y_train'], z_train, NN, 'crossentropy', training_options);
Results = testnet(NN, [x_test', y_test'], z_test, "crossentropy");

%% Visualization: Generate 3D Plots
% Create a grid for x and y
[x_grid, y_grid] = meshgrid(-10:0.5:10, -10:0.5:10);
grid_points = [x_grid(:), y_grid(:)];

% Predict using the neural network
predictions = predict(NN, grid_points')'; % Neural network predictions
pred_classes = predictions(:, 1) > predictions(:, 2); % Class 1 if positive, else Class 2

% Compute original function output for comparison
z_orig = x_grid .* y_grid + 1; % Original function

% Reshape predictions for plotting
z_pred = reshape(pred_classes, size(x_grid));

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
surf(x_grid, y_grid, double(z_pred)); % Convert logical to double for visualization
title('Neural Network Predictions (Positive/Negative)');
xlabel('x');
ylabel('y');
zlabel('Class');
colormap('jet');
colorbar;