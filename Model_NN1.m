% Data Hyper-parameters =============================================
start_month = 201001;
end_month = 202212;

INITIAL_BALANCE = 10000;        %10 k
TC = 0.0010;                    %10 bps
STOCKS_EACH_DAY = 30;
% ===================================================================

total_months = end_month - start_month;
years = floor(total_months/100);
total_months = total_months - 100*years + 12*years;

% Spcify hyperparameters for neural network
options = trainingOptions("sgdm", ...
    LearnRateSchedule="piecewise", ...
    ExecutionEnvironment="cpu", ...
    LearnRateDropFactor=0.2, ...
    LearnRateDropPeriod=5, ...
    MaxEpochs=1, ...
    MiniBatchSize=128, ...
    Plots="none" ... % 'none' or 'traing-progress'
    );


NN = [
    featureInputLayer(3,"Name","I")
    fullyConnectedLayer(16,"Name","H1")
    reluLayer("Name","relu")
    fullyConnectedLayer(1,"Name","H2")
    functionLayer(@(x)(nthroot(x,3)/3),"Name",'O',"Description",'@(x) (nthroot(x, 3) / 3);')
];

for i = 1:total_months

    %Loop variables -----------------------------------------------
    i_month = months_add(start_month,i-1);
    good_in_current_month = loaddata('good_now',i_month,i_month);
    days_in_current_month = size(good_in_current_month,2);
    % ------------------------------------------------------------

    rtxm_morning = loaddata('rtxm_byti',i_month,i_month,3);
    rtxm_lunch = loaddata('rtxm_byti',i_month,i_month,4);
    rtxm_afternoon = loaddata('rtxm_byti',i_month,i_month,5);
    vol_morning = loaddata("volcum_bytm",i_month,i_month,2);

    for j = 1:days_in_current_month

        X_1 = rtxm_morning(:,j);
        X_2 = rtxm_lunch(:,j);
        X_3 = vol_morning(:,j);
        Y = rtxm_afternoon(:,j);

        good_today = good_in_current_month(:,j);
        good_today = good_today & ~isnan(X_1) & ~isnan(X_2) & ~isnan(X_3) & ~isnan(Y);

        X_3 =  (X_3 - mean(X_3(good_today))) ./ std(X_3(good_today)); % Normalize 

        X = [ X_1(good_today) X_2(good_today) X_3(good_today) ];
        Y = Y(good_today);

        NN = trainnet(X,Y,NN,'mse',options);

    end


end

% Function to increase date by months:
function date = months_add(base_date,months_added)
    years = floor(months_added/12);
    months = mod(months_added,12);
    date = base_date + 100*years + months;
    if mod(date,100) > 12
        date = date + 88;
    end
end
