% Parameters and Hyperparameters ===============================
start_month = 201001;
end_month = 202212;

INITIAL_BALANCE = 10000;        % 10k
TC = 0.0010;                    % 10 bps
STOCKS_EACH_DAY = 30;

% Neural Network Hyperparameters
options = trainingOptions("adam", ...
    LearnRateSchedule = "polynomial", ...
    MaxEpochs = 1, ... 
    MiniBatchSize = 128, ...
    ExecutionEnvironment = "cpu", ...
    Verbose=false, ...
    Plots = "none");

NN = [
    featureInputLayer(3, "Name", "InputLayer")
    fullyConnectedLayer(32, "Name", "HiddenLayer1","WeightsInitializer", "he") 
    reluLayer("Name", "ReLU")
    dropoutLayer(0.2, "Name", "Dropout") 
    fullyConnectedLayer(1, "Name", "OutputLayer","WeightsInitializer", "glorot")
    sigmoidLayer("Name", "SigmoidOutput") 
];
NN = dlnetwork(NN);

% ==============================================================

% Initialize Variables ===============================================
total_months = calculate_total_months(start_month, end_month);
balance = INITIAL_BALANCE;

% Initialize Results Arrays:
monthly_mr = zeros(1,total_months-ROLLOVER);
monthly_balance = zeros(1,total_months-ROLLOVER);
monthly_traded_mr = zeros(1,total_months-ROLLOVER);

traded_ff = NaN(STOCKS_EACH_DAY,31,total_months-ROLLOVER);
traded_yy = NaN(STOCKS_EACH_DAY,31,total_months-ROLLOVER);
% ===================================================================

% Main Loop ====================================================
tic;

for i = 1:total_months

    i_month = increment_month(start_month, i - 1);

    [X_data, Y_data] = prepare_month_data(i_month);

    [accuracy, correct_predictions, total_predictions, balance, mean, sd, acc_50, acc_20, acc_5] = calculate_statistics(NN, X_data, Y_data);

    fprintf("Accuracy: %.2f%% (%d/%d correct predictions)\n", accuracy, correct_predictions, total_predictions);

    NN = trainnet(X_data, Y_data, NN, 'mse', options);

end

toc
% ==============================================================

% Functions ====================================================

function total_months = calculate_total_months(start_month, end_month)
    years = floor((end_month - start_month) / 100);
    months = mod(end_month - start_month, 100);
    total_months = years * 12 + months;
end

function new_date = increment_month(base_date, months_to_add)
    years = floor(months_to_add / 12);
    months = mod(months_to_add, 12);
    new_date = base_date + years * 100 + months;
    if mod(new_date, 100) > 12
        new_date = new_date + 88;
    end
end

function [X, Y] = prepare_month_data(i_month)
    
    good_today = loaddata('good_now', i_month, i_month);
    rtxm_morning = loaddata('rtxm_byti', i_month, i_month, 3);
    rtxm_lunch = loaddata('rtxm_byti', i_month, i_month, 4);
    rtxm_afternoon = loaddata('rtxm_byti', i_month, i_month, 5);
    vol_morning = loaddata('volcum_bytm', i_month, i_month, 2);

    valid_rows = good_today & all(~isnan([rtxm_morning, rtxm_lunch, vol_morning, rtxm_afternoon]), 2);

    % Normalize and Generate X
    X_1 = normalize_feature(rtxm_morning(valid_rows));
    X_2 = normalize_feature(rtxm_lunch(valid_rows));
    X_3 = normalize_feature(vol_morning(valid_rows));
    X = [X_1, X_2, X_3];

    % Generate Y
    Y = rtxm_afternoon(valid_rows);
    Y = Y > 0;
    Y = double(Y);
end

function X_norm = normalize_feature(feature)
    X_norm = (feature - mean(feature)) / std(feature);
end

function [accuracy, correct_predictions, total_predictions, balance, avg, sd, acc_50, acc_20, acc_5] = calculate_statistics(NN, X, Y)
    predictions = predict(NN,X);
    predicted_labels = predictions > 0.5;

    correct_predictions = sum(predicted_labels == Y);
    total_predictions = numel(Y);
    accuracy = correct_predictions / total_predictions * 100;

    balance = sum(predicted_labels) / total_predictions * 100;
    avg = mean(predictions);
    sd = std(predictions);

end

% ==============================================================