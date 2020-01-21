% Toolbox for batch processing ASL perfusion based fMRI data.
% All rights reserved.
% Ze Wang @ TRC, CFN, Upenn 2004
%
%
% Smoothing batch file for SPM2

global PAR fidLog;
if (fidLog<=0), fidLog=1; end  %if fidLog is not previously defined, set to 1 to send output to screen
fprintf(fidLog,'\n%s: Creating brain mask\n', datestr(datetime('now')));
par;

disp('Creating brain mask image ....');
org_pwd=pwd;
% dirnames,
% get the subdirectories in the main directory
for s = 1:PAR.nsubs % for each subject
   for c=1:PAR.ncond
      str   = sprintf('-- processing subject/condition: #%d/%d  (''%s''/''%s'')',s, c,PAR.subjects{s},PAR.sessionfilters{c} );
      fprintf(fidLog, '%s\n',str);
      
      meanimg=spm_select('FPList', PAR.condirs{s,c}, ['^mean' PAR.confilters{1} '\w*\.nii$']);
      brainmaskfile = ASLtbx_createbrainmask(meanimg);
      fprintf(fidLog,'   Created brain mask file: %s\n', brainmaskfile );    
   end
end