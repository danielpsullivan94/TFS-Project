%% GE Data Input

GE_data = xlsread('FULL LOAD PERFORMANCE LM2500+ G4 (1).xlsx', 1, 'B34:W56');
GE_Power = GE_data(1, :) / 1000;                %kW to MW, Net Power
GE_T48 = GE_data(18, :);                        %GE HPT Exit Temperature
GE_fuelflow_hr = GE_data(7, :);                 %GE fuel mass flow rate [lb/hr]
GE_fuelflow_s = GE_fuelflow_hr / 3600;          %GE fuel mass flow rate [lb/s]
GE_exhaustflow = GE_data(22, :);                %GE exhaust mass flow rate
GE_massflow = GE_exhaustflow - GE_fuelflow_s;   %GE inlet mass flow rate
GE_SFC = GE_fuelflow_hr ./ (GE_Power*1E3);      %GE specific fuel consumption

%% Input operating parameters English Units
%The following parameters must be set to 0 if they are unknown before
%solving the cycle: LPT_Work, HPT_eff, LPT_eff, and
%LPT_Efficiency

T1_e = 65;              %Fahrenheit
P1_e = 14.417;          %psi
RH1 = .6;               %Relative Humidity
mflow_DA_e = 189.7;     %Mass flow rate of dry air, lb/s
LHV_e = 20185;          %BTU/lb
LPT_Work = 0;           %Uknown, must be set to 0 becuase of the if statements in turbine class constructor
HPT_OutletPressure = 0; %Unknown, and used in if statements in the turbine class constructor

%% Input Design Parameters

T4_e = 2200;            %Fahrenheit, maximum temp
VIGV_dP_e = 4;          %in H20, pressure drop across IGV
Ex_dP_e = 10;           %in H20, pressure drop across exhaust
LPC_eff = .82;          %LPC efficiency
r_LPC = 6;              %LPC Compression Ratio
r_HPC = 4;              %HPC Compress Ratio
HPC_eff  = .84;         %HPC Isentropic Efficiency
LPT_eff = .9476;        %LPT Isentropic Efficiency calculated with nominal case
HPT_eff = .9727;        %HPT Isentropic Efficiency calculated with nominal case
Generator_eff = .977;   %Given Generator Efficiency

%% Input Operating parameters converted to SI

T1 = (T1_e+459.67) * (5/9);                  %K
P1 = 6.89476*P1_e;                           %kPa
mflow_DA = mflow_DA_e * 0.453592;            %Dry air mass flow rate, kg/s
LHV = 2.326 * LHV_e;                         %kJ/kg

%% Inlet Design Parameters converted to SI

T4 = (T4_e+459.67) * (5/9);           %K
VIGV_dP = 0.249088908333 * VIGV_dP_e; %converting in H20 to kPa
Ex_dP = 0.249088908333 * Ex_dP_e;     %converting in H20 to kPa
P5 = P1 + Ex_dP;                      %Calculating LPT outlet pressure

%% Output Arrays

Net_Work(22) = zeros;                %kW
cycle_Eff(22) = zeros;
FuelMassFlowRate(22) = zeros;        %lbm/hr
HeatRate (22) = zeros;               %BTU/kW-hr
SpecificFuelConsumption(22) = zeros; %lbm/kW-hr
T48 = zeros(1, 22);                  %HPT Exit Temperature
P = zeros(8, 22);                    %Pressure at each station at each inlet temperature
T = zeros(8, 22);                    %Temperature at each station at each inlet temperature

%% Variable Mass Flow Rate

Vary_mdot_flag = 1;                               %boolean for turning on variable mass flow rate

%% Solve

for i=1:22   %iterating through all temperatures in the excel data sheet

    T1 = (5*i+459.67) * (5/9);

    %Inlet Ideal Gas Mixture
    InletAir = WetAir(RH1,T1,P1);                   %Create a WetAir object with the input temp, relative Humidity, and pressure.
    if(Vary_mdot_flag == 1)                         %vary mass flow rate?
        MassFlow_total = GE_massflow(i) * 0.453592; %calculate total mass flow rate given dry air flow rate, kg/s
    else
        MassFlow_total = (1+InletAir.X(2)/InletAir.X(1)) * mflow_DA; %calculate total mass flow rate given dry air flow rate, kg/s    
    end    

    %Staion 1
    Node1 = Node(1);
    Node1.T = T1;
    Node1.P = P1;
    T(1, i) = T1;
    P(1, i) = P1;
    Fluid1 = WorkingFluid(InletAir.Y,Node1);

    %Solving for Station 2
    VIGV1 = GuideVane(Node1,VIGV_dP,2);
    Node2 = VIGV1.OutletNode;
    Fluid2 = WorkingFluid(InletAir.Y, Node2);
    Node2.h = Fluid2.H;
    T(2, i) = VIGV1.OutletT;
    P(2, i) = VIGV1.OutletP;

    %Solving for station 25
    LPC = Compressor(Node2,Fluid2, LPC_eff, r_LPC, 25);
    Node25 = LPC.OutletNode;
    Fluid25 = WorkingFluid(InletAir.Y, Node25);
    T(3, i) = LPC.To_a;
    P(3, i) = LPC.OutletNode.P;

    %Solving for station 3
    HPC = Compressor(Node25, Fluid25, HPC_eff, r_HPC, 3);
    HPC.OutletNode.T = HPC.To_a;
    Node3 = HPC.OutletNode;
    Fluid3 = WorkingFluid(InletAir.Y, Node3);
    T(4, i) = HPC.To_a;
    P(4, i) = HPC.OutletNode.P;

    %Solving for station 4
    Combustor1 = Combustor(Node3,Fluid3, T4, 4);
    Node4 = Combustor1.OutletNode;
    Fluid4 = WorkingFluid(InletAir.Y, Node4);
    T(5, i) = Combustor1.To_a;
    P(5, i) = Combustor1.OutletNode.P;

    %Solving for station 48
    HPT = Turbine(Node4, Fluid4, HPT_eff, HPT_OutletPressure, LPC.Work + HPC.Work, 48);
    Node48 = HPT.OutletNode;
    Fluid48 = WorkingFluid(InletAir.Y, Node48);
    T(6, i) = HPT.To_a;
    P(6, i) = HPT.P_out;

    %Solving for station 5
    LPT = Turbine(Node48, Fluid48, LPT_eff, P5, 0, 5); 
    Node5 = LPT.OutletNode;
    Fluid5 = WorkingFluid(InletAir.Y, Node5);
    T(7, i) = LPT.To_a;
    P(7, i) = LPT.P_out;

    %Solving for 6
    Exhaust = GuideVane(Node5, Ex_dP, 6);
    Node6 = Exhaust.OutletNode;
    Fluid6 = WorkingFluid(InletAir.Y, Node6);
    T(8, i) = Exhaust.OutletT;
    P(8, i) = Exhaust.OutletP;

    %Output Parameters
    cycle_Eff(i) = LPT.Work/(Node4.h - Node3.h); %calculate cycle efficiency
    Net_Work(i) = MassFlow_total * LPT.Work*Generator_eff; %calculate net work
    FuelMassFlowRate(i) = MassFlow_total*(Combustor1.ho_a - HPC.ho_a) / LHV; %lbm/hr
    HeatRate (i) = FuelMassFlowRate(i)*LHV / Net_Work(i); %BTU/kW-hr
    SpecificFuelConsumption(i) = FuelMassFlowRate(i) / Net_Work(i); %lbm/kW-hr

end

%% Unit Conversion

T_range_F = 5:5:110
Net_Work_Output = Net_Work*1E-3; %MW
FuelMassFlowRate_Output = FuelMassFlowRate*2.20462*3600 %lbm/hr
HeatRate_Output = FuelMassFlowRate_Output .*  LHV_e ./ (Net_Work_Output*1E3); %BTU/kW-hr 
SpecificFuelConsumption_Output = FuelMassFlowRate_Output ./ (Net_Work_Output*1E3); %lbm/kW-hr

%% Plots

figure(1);
plot(T_range_F, cycle_Eff, '*')                         %plots eff versus T
title('Cycle Efficiency versus Inlet Air Temperature')
xlabel('Inlet Air Temperature (\circF)')
ylabel('Cycle Efficiency')
legend('Simulation', 'Location', 'east');

figure(2)
plot(T_range_F, Net_Work_Output, '*', T_range_F, GE_Power, 'r*')                   %plots net work versus T
title('Net Work versus Inlet Air Temperature')
xlabel('Inlet Air Temperature (\circF)')
ylabel('Net Work (MW)')
legend('Simulation', 'GE Data',  'Location', 'east');

figure(3);
plot(T_range_F, FuelMassFlowRate_Output, '*', T_range_F, GE_fuelflow_hr, 'r*')           %plots mdotf versus T    
title('Fuel Mass Flow Rate versus Inlet Air Temperature')
xlabel('Inlet Air Temperature (\circF)')
ylabel('Fuel Mass Flow Rate (lb_m hr^{-1})')
legend('Simulation', 'GE Data');

figure(4);
plot(T_range_F, HeatRate_Output, '*')                   %plots hr versus T
title('Heat Rate versus Inlet Air Temperature')
xlabel('Inlet Air Temperature (\circF)')
ylabel('Heat Rate (BTU kW^{-1} hr^{-1})')
legend('Simulation', 'Location', 'east');

figure(5);
plot(T_range_F, SpecificFuelConsumption_Output, '*', T_range_F, GE_SFC, 'r*')    %plots sfc versus T
title('Specific Fuel Consumption versus Inlet Air Temperature')
xlabel('Inlet Air Temperature (\circF)')
ylabel('Specific Fuel Consumption (lb_m kW^{-1} hr^{-1})')
legend('Simulation', 'GE Data', 'Location', 'east');

figure(6);
hold on
xrange = 0:1:120;   %range for the line plot
T48_max = 1551;           %LPT Firing temperature?
plot(T_range_F, T(6, :), '*', T_range_F, GE_T48, 'r*');
plot([0 120], [1551 1551], 'r--');
title('HPT Exit Temperature versus Inlet Temperature');
xlabel('Inlet Air Temperature (\circF)');
ylabel('HPT Exit Temperature (\circF)');
legend('Simulation', 'GE Data', '1551 \circF', 'Location', 'east');
%% Write Tables

csvwrite('Station_Pressures.csv', P');
csvwrite('Station_Temperatures.csv', T');