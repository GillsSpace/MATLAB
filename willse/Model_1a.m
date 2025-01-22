% Start/End Months
start_month = 201001;
end_month = 202212;

% Data Hyper-paramaters:
ROLLOVER = 4;

% Time Frane
total_months = end_month - start_month;
years = floor(total_months/100);
total_months = total_months - 100*years + 12*years;


% Function to increase date by months:
function date = months_add(base_date,months_added)
    years = floor(months_added/12);
    months = mod(months_added,12);

    date = base_date + 100*years + months;

    if mod(date,100) > 12
        date = date + 88;
    end
end

% Initilize Signal Arrays:
a1a = zeros(1,total_months);
a1b = zeros(1,total_months);
a1c = zeros(1,total_months);
a2a = zeros(1,total_months);
a2b = zeros(1,total_months);
a2c = zeros(1,total_months);
a3a = zeros(1,total_months);
a3b = zeros(1,total_months);
a3c = zeros(1,total_months);
a4a = zeros(1,total_months);
a4b = zeros(1,total_months);
a4c = zeros(1,total_months);

c1a = zeros(1,total_months);
c1b = zeros(1,total_months);
c1c = zeros(1,total_months);
c1d = zeros(1,total_months);
c1e = zeros(1,total_months);
c1f = zeros(1,total_months);

i = 1;
tic;
while i <= total_months - ROLLOVER + 1
    
    %Loop variables
    i_start = months_add(start_month,i-1);
    i_end = months_add(start_month,ROLLOVER+i-2);

    %Data Loadings and Cleaning
    rtxm_yesterday = loaddata("rtxm_byti",i_start,i_end,2); %day(1) - day(end-1)
    vol_yesterday = loaddata("volall_day",i_start,i_end,1); %day(1) - day(end-1)

    rtxm_lastnight = loaddata("rtxm_byti",i_start,i_end,1); %day(2) - day(end)
    rtxm_today = loaddata("rtxm_byti",i_start,i_end,2); %day(2) - day(end)
    rtxm_morning = loaddata("rtxm_byti",i_start,i_end,3); %day(2) - day(end)
    rtxm_lunch = loaddata("rtxm_byti",i_start,i_end,4); %day(2) - day(end)
    rtxm_afternoon = loaddata("rtxm_byti",i_start,i_end,5); %day(2) - day(end)
    vol_today = loaddata("volall_day",i_start,i_end,1); %day(2) - day(end) --- Not Curently Used
    vol_morning = loaddata("volcum_bytm",i_start,i_end,2); %day(2) - day(end)
    vol_afternoon = vol_today - vol_morning; %day(2) - day(end) --- Not Curently used

    rtxm_yesterday = rtxm_yesterday(:,1:end-1);
    vol_yesterday = vol_yesterday(:,1:end-1);

    rtxm_lastnight = rtxm_lastnight(:,2:end);
    rtxm_today = rtxm_today(:,2:end);
    rtxm_morning = rtxm_morning(:,2:end);
    rtxm_lunch = rtxm_lunch(:,2:end);
    rtxm_afternoon = rtxm_afternoon(:,2:end);
    vol_today = vol_today(:,2:end); 
    vol_morning = vol_morning(:,2:end);
    vol_afternoon = vol_afternoon(:,2:end); 

    good = loaddata("good_now",i_start,i_end);
    good = good(:, 1:end-1) & good(:,2:end) == 1;
    good = good & ~isnan(rtxm_yesterday) & ~isnan(vol_yesterday)...
        & ~isnan(rtxm_lastnight) & ~isnan(rtxm_today) & ~isnan(rtxm_morning) & ~isnan(rtxm_lunch) & ~isnan(rtxm_afternoon)...
        & ~isnan(vol_today) & ~isnan(vol_morning) & ~isnan(vol_afternoon);

    %Prediction Time 9:31
    a1a(i) = regress(rtxm_today(good),rtxm_yesterday(good));
    a1b(i) = regress(rtxm_today(good),vol_yesterday(good));
    a1c(i) = regress(rtxm_today(good),rtxm_lastnight(good));

    a2a(i) = regress(rtxm_morning(good),rtxm_yesterday(good)); 
    a2b(i) = regress(rtxm_morning(good),vol_yesterday(good)); 
    a2c(i) = regress(rtxm_morning(good),rtxm_lastnight(good));

    a3a(i) = regress(rtxm_lunch(good),rtxm_yesterday(good)); 
    a3b(i) = regress(rtxm_lunch(good),vol_yesterday(good)); 
    a3c(i) = regress(rtxm_lunch(good),rtxm_lastnight(good));

    a4a(i) = regress(rtxm_afternoon(good),rtxm_yesterday(good)); 
    a4b(i) = regress(rtxm_afternoon(good),vol_yesterday(good)); 
    a4c(i) = regress(rtxm_afternoon(good),rtxm_lastnight(good));

    %Prediction Time 9:31
    c1a(i) = a4a(i);
    c1b(i) = a4b(i);
    c1c(i) = a4c(i);
    c1d(i) = regress(rtxm_afternoon(good),rtxm_morning(good));
    c1e(i) = regress(rtxm_afternoon(good),vol_morning(good));
    c1f(i) = regress(rtxm_afternoon(good),rtxm_lunch(good));


    %Loop progression
    i = i + 1;

end
toc

fa1 = figure;
plot(1:total_months,a1a,'-r',...
    1:total_months,a1b,'-b',...
    1:total_months,a1c,'-g')
fa2 = figure;
plot(1:total_months,a2a,'-r',...
    1:total_months,a2b,'-b',...
    1:total_months,a2c,'-g')
fa3 = figure;
plot(1:total_months,a3a,'-r',...
    1:total_months,a3b,'-b',...
    1:total_months,a3c,'-g')
fa4 = figure;
plot(1:total_months,a4a,'-r',...
    1:total_months,a4b,'-b',...
    1:total_months,a4c,'-g')

fc1 = figure;
plot(1:total_months,c1a,'-r',...
    1:total_months,c1b,'-b',...
    1:total_months,c1c,'-g',...
    1:total_months,c1d,'-y',...
    1:total_months,c1e,'-k',...
    1:total_months,c1f,'-c')


% predictions:
% at 09:31 -> predict [full day, morning, lunch, afternoon]
% at 11:28 -> predict [lunch, afternoon]
% at 13:01 -> predict [afternoon]
