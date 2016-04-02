% GUI backend for Rappture
%
% Rappture documentation available at http://rapture.org
%
% Copyright (C) 2014--2016 Stephen J. Polly and Alex J. Grede
% GPL v3, See LICENSE for details
% This function is part of straincomp (https://nanohub.org/resources/straincomp)
% ----------------------------------------------------------------------
%  MAIN PROGRAM - generated by the Rappture Builder
% ----------------------------------------------------------------------

% open the XML file containing the run parameters
% the file name comes in from the command-line via variable 'infile'
io = rpLib(infile);

MProps = loadjson('master.json');


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Get input values from Rappture
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% get input value for input.number(QDDia) and convert to nm
str = rpLibGetString(io,'input.number(QDDia).current');
[QDDia,err] = rpUnitsConvertDbl(str, 'nm');

% get input value for input.number(QDH) and convert to nm
str = rpLibGetString(io,'input.number(QDH).current');
[QDH,err] = rpUnitsConvertDbl(str, 'nm');

% get input value for input.number(QDDen) and convert to cm-2
str = rpLibGetString(io,'input.number(QDDen).current');
[QDDen,err] = rpUnitsConvertDbl(str, 'cm-2');

% get input value for input.number(WL) and convert to nm
str = rpLibGetString(io,'input.number(WL).current');
[WL,err] = rpUnitsConvertDbl(str, 'nm');

% get input values for layers
lyrs = {'Sub', 'QD', 'SC'};
lyrParam = struct;
tmp = {'A','B'};
for k0=1:length(lyrs)
  lyrParam.(lyrs{k0}) = struct;
  lyrParam.(lyrs{k0}).groupA = {'Al', 'Ga', 'In'};
  lyrParam.(lyrs{k0}).groupB = {'P', 'As', 'Sb'};
  lyrParam.(lyrs{k0}).weightsA = [0, 0, 0];
  lyrParam.(lyrs{k0}).weightsB = [0, 0, 0];
  lyrParam.(lyrs{k0}).crystalStructure = 'ZBB';
  for k=1:length(tmp)
    tdbl = zeros(1,3);
    tmplc = tolower(tmp{k});
    elmnts = lyrParam.(lyrs{k0}).(strcat('group',tmp{k}));
    for l=1:length(elmnts)
      [tdbl(l),err] = rpLibGetDouble(io, ...
                        strcat('input.group(', lyrs{k0}, ...
                               ').group(group_',...
                               tmplc,').number(',elmnts{l},').current'));
    endfor
    lyrParam.(lyrs{k0}).(strcat('group',tmp{k})) = lyrParam.(lyrs{k0}).(...
                                                       strcat('group',tmp{k}))(logical(tdbl>0));
    lyrParam.(lyrs{k0}).(strcat('weights',tmp{k})) = tdbl(logical(tdbl>0));
  endfor
endfor


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%  Add your code here for the main body of your program
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% spit out progress messages as you go along...
%rpUtilsProgress(0, 'Starting...');
%rpUtilsProgress(5, 'Loading data...');
%rpUtilsProgress(50, 'Half-way there');
%rpUtilsProgress(100, 'Done');
%%
% Unit Conversions -----------------------------------------
QDDensity=QDDen * 1e-16; %Angstrom^-2 {5e-6 A^-2 = 5e10 cm^-2}
QDDiameter=QDDia * 10; %Angstrom
QDHeight=QDH * 10; %Angstrom
WLThickness=WL * 10; %Angstrom

% Parse Material Selection ---------------------------------
[aSub,c11iSub,c12iSub,c11aSub,c12aSub] = semiProps(lyrParam.Sub, MProps);

[aQD,c11iQD,c12iQD,c11aQD,c12aQD] = semiProps(lyrParam.QD, MProps);

[aSC,c11iSC,c12iSC,c11aSC,c12aSC] = semiProps(lyrParam.SC, MProps);


% Stiffness Calculations ----------------------------------
%Interpolated stiffness ratios
ASCi=c11iSC + c12iSC - (2*c12iSC.^2./c11iSC);
AQDi=c11iQD + c12iQD - (2*c12iQD.^2./c11iQD);

%Adachi equation stiffness ratios
ASCa=c11aSC + c12aSC - (2*c12aSC.^2./c11aSC);
AQDa=c11aQD + c12aQD - (2*c12aQD.^2./c11aQD);


% QD Volume Calculations -----------------------------------
% QD as spherical cap
vQDSphCap=pi.*QDHeight./6 .* (3 .*(QDDiameter/2).^2 + QDHeight.^2); %[A^3]

% QD as cylinder
QDsigma=(QDDiameter/2)^2*pi; %QD base area [A^2]
vQDCyl=QDHeight*QDsigma; %[A^3]

% QD as oblate hemispheroid
vQDOblSph=((4/3)*pi*(QDDiameter/2)^2*QDHeight)/2; %[A^3]

% Strain Compensation Calculations -------------------------
% CET QD Thickness
CETQDi=QDHeight*((AQDi .* aSC^2 .* (aSub - aQD))./(ASCi .* aQD^2 .* (aSC - aSub))); %[A]
CETQDa=QDHeight*((AQDa .* aSC^2 .* (aSub - aQD))./(ASCa .* aQD^2 .* (aSC - aSub))); %[A]

%CET WL Thickness
CETWLi=WLThickness*((AQDi .* aSC^2 .* (aSub - aQD))./(ASCi .* aQD^2 .* (aSC - aSub))); %[A]
CETWLa=WLThickness*((AQDa .* aSC^2 .* (aSub - aQD))./(ASCa .* aQD^2 .* (aSC - aSub))); %[A]

%Effective coverage of QD material (Cylinder)
tQDWLCyl=(QDsigma*QDDensity)*QDHeight+(1-QDsigma*QDDensity)*WLThickness; %[A]

%mCET Cylinder weighted SC thickness
mCETcyli=(QDsigma*QDDensity)*CETQDi + (1-QDsigma*QDDensity)*CETWLi; %[A]
mCETcyla=(QDsigma*QDDensity)*CETQDa + (1-QDsigma*QDDensity)*CETWLa; %[A]

%Effective coverage of QD material (Oblate Hemispheroid)
tQD=vQDOblSph*QDDensity; %average thickness of QD per area [A]
tQDWL=WLThickness+tQD; %WL is treated as external to QD [A]

%mCET Oblate Hemispheroid
mCETsphi=tQDWL*((AQDi .* aSC^2 .* (aSub - aQD))./(ASCi .* aQD^2 .* (aSC - aSub))); %[A]
mCETspha=tQDWL*((AQDa .* aSC^2 .* (aSub - aQD))./(ASCa .* aQD^2 .* (aSC - aSub))); %[A]

%Interpolated stiffness ratios
ASCi=c11iSC + c12iSC - (2*c12iSC.^2./c11iSC);
AQDi=c11iQD + c12iQD - (2*c12iQD.^2./c11iQD);

%Adachi equation stiffness ratios
ASCa=c11aSC + c12aSC - (2*c12aSC.^2./c11aSC);
AQDa=c11aQD + c12aQD - (2*c12aQD.^2./c11aQD);

%Effective lattice constant of CET
a0SLQDCETi=edzerostress(AQDi, QDHeight, aQD, ASCi, CETQDi, aSC); %[A]
a0SLQDCETa=edzerostress(AQDa, QDHeight, aQD, ASCa, CETQDa, aSC); %[A]

%Effective lattice constant of mCET Cylinder
%QD
a0SLQDmCETcyli=edzerostress(AQDi, QDHeight, aQD, ASCi, mCETcyli, aSC); %[A]
a0SLQDmCETcyla=edzerostress(AQDa, QDHeight, aQD, ASCa, mCETcyla, aSC); %[A]
%WL
a0SLWLmCETcyli=edzerostress(AQDi, WLThickness, aQD, ASCi, mCETcyli, aSC); %[A]
a0SLWLmCETcyla=edzerostress(AQDa, WLThickness, aQD, ASCa, mCETcyla, aSC); %[A]

%Effective lattice constant of mCET Oblate Hemispheroid
%QD
a0SLQDmCETsphi=edzerostress(AQDi, QDHeight+ + WLThickness, aQD, ASCi, mCETsphi, aSC); %[A]
a0SLQDmCETspha=edzerostress(AQDa, QDHeight+ + WLThickness, aQD, ASCa, mCETspha, aSC); %[A]
%WL
a0SLWLmCETsphi=edzerostress(AQDi, WLThickness, aQD, ASCi, mCETsphi, aSC); %[A]
a0SLWLmCETspha=edzerostress(AQDa, WLThickness, aQD, ASCa, mCETspha, aSC); %[A]

%Calculation of tetragonally distorted lattice constant
a0pQDi=(aQD-aSub)*(1 + 2 * c12iQD/c11iQD)+aSub; %[A]
a0pQDa=(aQD-aSub)*(1 + 2 * c12aQD/c11aQD)+aSub; %[A]

a0pSCi=(aSC-aSub)*(1 + 2 * c12iSC/c11iSC)+aSub; %[A]
a0pSCa=(aSC-aSub)*(1 + 2 * c12aSC/c11aSC)+aSub; %[A]

%Calculation of absolute misfit strain
e0QD=(aQD-aSub)/aSub;
e0SC=(aSC-aSub)/aSub;

%Calculation of absolute effective misfit strain CET
e0SLQDCETi=(aSub-a0SLQDCETi)/aSub;
e0SLQDCETa=(aSub-a0SLQDCETa)/aSub;

%Calculation of absolute effective misfit strain mCET Cylinder
%QD
e0SLQDmCETcyli=(a0SLQDmCETcyli-aSub)/aSub;
e0SLQDmCETcyla=(a0SLQDmCETcyla-aSub)/aSub;
%WL
e0SLWLmCETcyli=(a0SLWLmCETcyli-aSub)/aSub;
e0SLWLmCETcyla=(a0SLWLmCETcyla-aSub)/aSub;

%Calculation of absolute effective misfit strain mCET Oblate Hemispheroid
%QD
e0SLQDmCETsphi=(a0SLQDmCETsphi-aSub)/aSub;
e0SLQDmCETspha=(a0SLQDmCETspha-aSub)/aSub;
%WL
e0SLWLmCETsphi=(a0SLWLmCETsphi-aSub)/aSub;
e0SLWLmCETspha=(a0SLWLmCETspha-aSub)/aSub;

%Calculation of Poisson Ratio
nuSubi=c12iSub/(c11iSub+c12iSub);
nuSuba=c12aSub/(c11aSub+c12aSub);

nuQDi=c12iQD/(c11iQD+c12iQD);
nuQDa=c12aQD/(c11aQD+c12aQD);

nuSCi=c12iSC/(c11iSC+c12iSC);
nuSCa=c12aSC/(c11aSC+c12aSC);

%Pick the largest Poisson ratio to err toward underestimate of hc
if nuQDi > nuSCi
    nui=nuQDi;
else
    nui=nuSCi;
end

if nuQDa > nuSCa
    nua=nuQDa;
else
    nua=nuSCa;
end

alpha=pi/3;
lambda=pi/3;
%%
%Calculation of critical SL thickness CET
hcCETi=matthewsblakeslee(1,a0SLQDCETi,e0SLQDCETi,nui,alpha,lambda,0.001); %[A]
hcCETa=matthewsblakeslee(1,a0SLQDCETa,e0SLQDCETa,nua,alpha,lambda,0.001); %[A]

%Calculation of critical SL thickness mCET Cylinder
%QD
hcmCETQDcyli=matthewsblakeslee(1,a0SLQDmCETcyli,e0SLQDmCETcyli,nui,alpha,lambda,0.001); %[A]
hcmCETQDcyla=matthewsblakeslee(1,a0SLQDmCETcyla,e0SLQDmCETcyla,nua,alpha,lambda,0.001); %[A]
%WL
hcmCETWLcyli=matthewsblakeslee(1,a0SLWLmCETcyli,e0SLWLmCETcyli,nui,alpha,lambda,0.001); %[A]
hcmCETWLcyla=matthewsblakeslee(1,a0SLWLmCETcyla,e0SLWLmCETcyla,nua,alpha,lambda,0.001); %[A]

%Calculation of critical SL thickness mCET Oblate Hemispheroid
%QD
hcmCETQDsphi=matthewsblakeslee(1,a0SLQDmCETsphi,e0SLQDmCETsphi,nui,alpha,lambda,0.001); %[A]
hcmCETQDspha=matthewsblakeslee(1,a0SLQDmCETspha,e0SLQDmCETspha,nua,alpha,lambda,0.001); %[A]
%WL
hcmCETWLsphi=matthewsblakeslee(1,a0SLWLmCETsphi,e0SLWLmCETsphi,nui,alpha,lambda,0.001); %[A]
hcmCETWLspha=matthewsblakeslee(1,a0SLWLmCETspha,e0SLWLmCETspha,nua,alpha,lambda,0.001); %[A]

%Calculation of critical SL repeat units CET
maxCETi=floor(hcCETi/(CETQDi+QDHeight));
maxCETa=floor(hcCETa/(CETQDa+QDHeight));

%Calculation of critical SL repeat units mCET Cylinder
%QD
maxmCETQDcyli=floor(hcmCETQDcyli/(mCETcyli+max([QDHeight WLThickness])));
maxmCETQDcyla=floor(hcmCETQDcyla/(mCETcyla+max([QDHeight WLThickness])));
%SC
maxmCETWLcyli=floor(hcmCETWLcyli/(mCETcyli+max([QDHeight WLThickness])));
maxmCETWLcyla=floor(hcmCETWLcyla/(mCETcyla+max([QDHeight WLThickness])));

%Calculation of critical SL repeat units mCET Oblate Hemispheroid
%QD
maxmCETQDsphi=floor(hcmCETQDsphi/(mCETsphi+QDHeight+WLThickness));
maxmCETQDspha=floor(hcmCETQDspha/(mCETspha+QDHeight+WLThickness));
%SC
maxmCETWLsphi=floor(hcmCETWLsphi/(mCETsphi+QDHeight+WLThickness));
maxmCETWLspha=floor(hcmCETWLspha/(mCETspha+QDHeight+WLThickness));

%Calculation of maximum SL repeat units mCET Cylinder
[opthcmCETcyli, mCETcylOpti, optmaxmCETcyli]=weightedStrainOpt(1,1,AQDi,ASCi,aSub,aQD,aSC,QDHeight,WLThickness,mCETcyli,nui,alpha,lambda,0.001);
[opthcmCETcyla, mCETcylOpta, optmaxmCETcyla]=weightedStrainOpt(1,1,AQDa,ASCa,aSub,aQD,aSC,QDHeight,WLThickness,mCETcyla,nua,alpha,lambda,0.001);
optmaxmCETcyli=floor(optmaxmCETcyli);
optmaxmCETcyla=floor(optmaxmCETcyla);

%Calculation of maximum SL repeat units mCET Oblate Hemispheroid
[opthcmCETsphi, mCETsphOpti, optmaxmCETsphi]=weightedStrainOpt(1,1,AQDi,ASCi,aSub,aQD,aSC,QDHeight+WLThickness,WLThickness,mCETsphi,nui,alpha,lambda,0.001);
[opthcmCETspha, mCETsphOpta, optmaxmCETspha]=weightedStrainOpt(1,1,AQDa,ASCa,aSub,aQD,aSC,QDHeight+WLThickness,WLThickness,mCETspha,nua,alpha,lambda,0.001);
optmaxmCETsphi=floor(optmaxmCETsphi);
optmaxmCETspha=floor(optmaxmCETspha);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Save output values back to Rappture
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Useful functions for output
printHeader = @(hdrs,cols) rpLibPutString(io,'output.log',...
                  sprintf('| %s |\n',strjoin(printCenter(hdrs, cols),' | ')),1);
printSep = @(cols) rpLibPutString(io,'output.log',...
                                  sprintf('%s\n', printDivider(cols+2)),1);
printH1 = @(hdr, cols) rpLibPutString(io,'output.log',...
                                      sprintf('\n%s %s\n', hdr,...
                                              repmat('=',...
                                                [1,sum(cols+3)+1-length(hdr)])),1);
findCols = @(hdrs, dataLength) max(cellfun(@length, hdrs), dataLength);


% Lit/Interp ============================================
hdrs = {'Mat', 'lc [A]', 'C11i[GPa]', 'C12i[GPa]', 'Poisson v', 'a_perp[A]',...
        'Misfit Strain'};
cols = findCols(hdrs, [0, 10.*ones(1,length(hdrs)-1)]);
printH1('Literature/Interpolated (i) Values', cols);
printSep(cols);
printHeader(hdrs, cols);
printSep(cols);
fmt1 = sprintf('| %s |\n', ...
               makeFormatStr({'s','e','e','e','e','e','esgn'}, cols, ' | '));
fmt2 = sprintf('| %s |\n', ...
             makeFormatStr({'s','e','e','e','e','blank','blank'}, cols, ' | '));

rpLibPutString(io,'output.log',...
               sprintf(fmt2,'Sub',aSub,c11iSub,c12iSub,nuSubi),1);
rpLibPutString(io,'output.log',...
               sprintf(fmt1,'QD',aQD,c11iQD,c12iQD,nuQDi,a0pQDi,e0QD),1);
rpLibPutString(io,'output.log',...
               sprintf(fmt1,'SC',aSC,c11iSC,c12iSC,nuSCi,a0pSCi,e0SC),1);
printSep(cols);

% Emp Calc ============================================
hdrs = {'Mat', 'C11e[GPa]', 'C12e[GPa]', 'Poisson v', 'a_perp[A]'};
cols = findCols(hdrs, [0, 10.*ones(1,length(hdrs)-1)]);
printH1('Empirically Calculated (e) Values', cols);
printSep(cols);
printHeader(hdrs, cols);
printSep(cols);
fmt1 = sprintf('| %s |\n', ...
               makeFormatStr({'s','e','e','e','e'}, cols, ' | '));
fmt2 = sprintf('| %s |\n', ...
               makeFormatStr({'s','e','e','e','blank'}, cols, ' | '));

rpLibPutString(io,'output.log',...
               sprintf(fmt2,'Sub',c11aSub,c12aSub,nuSuba),1);
rpLibPutString(io,'output.log',...
               sprintf(fmt1,'QD',c11aQD,c12aQD,nuQDa,a0pQDa),1);
rpLibPutString(io,'output.log',...
               sprintf(fmt1,'SC',c11aSC,c12aSC,nuSCa,a0pSCa),1);
printSep(cols);

% QD Volumes =======================================
printH1('QD Volumes [nm^3]', cols);  % Will use same ===... length (cols)
rpLibPutString(io,'output.log',sprintf('%9s: %0.4e\n','Sph. Cap',vQDSphCap/1000),1);
rpLibPutString(io,'output.log',sprintf('%9s: %0.4e\n','Cylinder',vQDCyl/1000),1);
rpLibPutString(io,'output.log',sprintf('%9s: %0.4e\n','Obl. Sph.',vQDOblSph/1000),1);

% Strain Compensation ==================================
hdrs1 = {'Params', 'Req. SC', 'Eff QD+WL Thick', 'Max SL'};
hdrs2 = {'Used', 'Thick[nm]', '[nm^3 cm^-2] or [nm]', 'Method'};
cols = findCols(hdrs1, findCols(hdrs2, [8, 10.*ones(1,length(hdrs1)-1)]));
fmt1 = sprintf('| %s |\n', makeFormatStr({'s','e','e','e'}, cols, ' | '));
fmt2 = sprintf('| %s |\n', makeFormatStr({'s','e','e','blank'}, cols, ' | '));
printH1('Strain Compensation',cols);
printSep(cols);
printHeader(hdrs1, cols);
printHeader(hdrs2, cols);
printSep(cols);
rpLibPutString(io,'output.log',...
               sprintf('| %-*s |\n', sum(3+cols)-3, 'CET (QD Height as QW)'),1);
printSep(cols);
rpLibPutString(io,'output.log',...
               sprintf(fmt2, 'Lit (i)', CETQDi/10, QDHeight/10),1);
rpLibPutString(io,'output.log',...
               sprintf(fmt2, 'Calc (e)', CETQDa/10, QDHeight/10),1);
printSep(cols);
rpLibPutString(io,'output.log',...
               sprintf('| %-*s |\n', sum(3+cols)-3, 'Modified CET (QD as Cylinder)'),1);
printSep(cols);
rpLibPutString(io,'output.log',...
               sprintf(fmt1, 'Lit (i)', mCETcyli/10, tQDWLCyl/10, mCETcylOpti),1);
rpLibPutString(io,'output.log',...
               sprintf(fmt1, 'Calc (e)', mCETcyla/10, tQDWLCyl/10, mCETcylOpta),1);
printSep(cols);
rpLibPutString(io,'output.log',...
               sprintf('| %-*s |\n', sum(3+cols)-3, 'Modified CET (QD as Oblate-Hemispheroid)'),1);
printSep(cols);
rpLibPutString(io,'output.log',...
               sprintf(fmt1, 'Lit (i)', mCETsphi/10, tQDWL/10, mCETsphOpti),1);
rpLibPutString(io,'output.log',...
               sprintf(fmt1, 'Calc (e)', mCETspha/10, tQDWL/10, mCETsphOpta),1);
printSep(cols);

% Superlattice Critical Thickness ==================================
hdrs1 = {'Params', 'Eff lc [A]', 'Eff Misfit', 'Crit SL', 'Crit SL','Max SL',...
         'Max SL'};
hdrs2 = {'Used', '', 'Strain', 'Thick [nm]', 'Units', 'Thick [nm]', 'Units'};
cols = findCols(hdrs1, findCols(hdrs2, [11, 10, 11, 10.*ones(1,length(hdrs1)-3)]));
fmt1 = sprintf('| %s |\n', makeFormatStr({'s','e','esgn','e','i','e','i'}, cols, ' | '));
fmt2 = sprintf('| %s |\n', makeFormatStr({'s','e','e','blank','blank','blank','blank'}, cols, ' | '));
printH1('Superlattice Critical Thickness', cols);
printSep(cols);
printHeader(hdrs1, cols);
printHeader(hdrs2, cols);
printSep(cols);
rpLibPutString(io,'output.log',...
               sprintf('| %-*s |\n', sum(3+cols)-3, 'CET (QD Height as QW)'),1);
printSep(cols);
rpLibPutString(io,'output.log',...
               sprintf(fmt2, 'Lit (i)', a0SLQDCETi, e0SLQDCETi),1);
rpLibPutString(io,'output.log',...
               sprintf(fmt2, 'Calc (e)', a0SLQDCETa, e0SLQDCETa),1);
printSep(cols);
rpLibPutString(io,'output.log',...
               sprintf('| %-*s |\n', sum(3+cols)-3, 'Modified CET (QD as Cylinder)'),1);
printSep(cols);
rpLibPutString(io,'output.log',...
               sprintf(fmt1, 'Lit (i) QD', a0SLQDmCETcyli, e0SLQDmCETcyli,...
                       hcmCETQDcyli, maxmCETQDcyli, opthcmCETcyli,...
                       optmaxmCETcyli),1);
rpLibPutString(io,'output.log',...
               sprintf(fmt1, 'Calc (e) QD', a0SLQDmCETcyla, e0SLQDmCETcyla,...
                       hcmCETQDcyla, maxmCETQDcyla, opthcmCETcyla,...
                       optmaxmCETcyla),1);
rpLibPutString(io,'output.log',...
               sprintf(fmt1, 'Lit (i) WL', a0SLWLmCETcyli, e0SLWLmCETcyli,...
                       hcmCETWLcyli, maxmCETWLcyli, opthcmCETcyli,...
                       optmaxmCETcyli),1);
rpLibPutString(io,'output.log',...
               sprintf(fmt1, 'Calc (e) WL', a0SLWLmCETcyla, e0SLWLmCETcyla,...
                       hcmCETWLcyla, maxmCETWLcyla, opthcmCETcyla,...
                      optmaxmCETcyla),1);
printSep(cols);
rpLibPutString(io,'output.log',...
               sprintf('| %-*s |\n', sum(3+cols)-3, 'Modified CET (QD as Oblate-Hemispheroid)'),1);
printSep(cols);
rpLibPutString(io,'output.log',...
               sprintf(fmt1, 'Lit (i) QD', a0SLQDmCETsphi, e0SLQDmCETsphi,...
                       hcmCETQDsphi, maxmCETQDsphi, opthcmCETsphi,...
                       optmaxmCETsphi),1);
rpLibPutString(io,'output.log',...
               sprintf(fmt1, 'Calc (e) QD', a0SLQDmCETspha, e0SLQDmCETspha,...
                       hcmCETQDspha, maxmCETQDspha, opthcmCETspha,...
                       optmaxmCETspha),1);
rpLibPutString(io,'output.log',...
               sprintf(fmt1, 'Lit (i) WL', a0SLWLmCETsphi, e0SLWLmCETsphi,...
                       hcmCETWLsphi, maxmCETWLsphi, opthcmCETsphi,...
                       optmaxmCETsphi),1);
rpLibPutString(io,'output.log',...
               sprintf(fmt1, 'Calc (e) WL', a0SLWLmCETspha, e0SLWLmCETspha,...
                       hcmCETWLspha, maxmCETWLspha, opthcmCETspha,...
                       optmaxmCETspha),1);
printSep(cols);

% Input values ===========================================================
hdrs = {'Input', 'Value'};
cols = findCols(hdrs, [15, 15]);
fmt1 = '| %15s | %-15s |\n';
fmt2 = '| %15s | %0.4e %-4s |\n';
printH1('Input values', cols);
printSep(cols);
printHeader(hdrs, cols);
printSep(cols);

tmp = {'A', 'B'};
lyrNms = {'Substrate', 'Quantum Dot', 'Strain Comp.'}
for k0=1:length(lyrs)
  mat = '';
  lyr = lyrs{k0};
  P = lyrParam.(lyr);
  for k=1:2
    elmnts = P.(strcat('group', tmp{k}));
    if length(elmnts) > 1
      for l=1:length(elmnts)
        ws = sprintf('%0.6f', P.(strcat('weights', tmp{k}))(l));
        mat = strcat(mat, elmnts{l}, ...
                     substr(ws, 1, length(ws)-1-regexp(ws, '[0]*$')));
      endfor
    else
      mat = strcat(mat, elmnts{1});
    endif
  endfor
  rpLibPutString(io, 'output.log',...
                 sprintf(fmt1, lyrNms{k0}, mat),1);
endfor

rpLibPutString(io,'output.log',...
               sprintf(fmt2, 'QD Diameter', QDDia, 'nm'),1);
rpLibPutString(io,'output.log',...
               sprintf(fmt2, 'QD/QW Height', QDH, 'nm'),1);
rpLibPutString(io,'output.log',...
               sprintf(fmt2, 'QD Density', QDDen, 'cm-2'),1);
rpLibPutString(io,'output.log',...
               sprintf(fmt2, 'WL Thickness', WL, 'nm'),1);
printSep(cols);
rpLibResult(io);
quit;
