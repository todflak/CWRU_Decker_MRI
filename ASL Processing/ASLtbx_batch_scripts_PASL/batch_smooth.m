% Toolbox for batch processing ASL perfusion based fMRI data.
% All rights reserved.
% Ze Wang @ TRC, CFN, Upenn 2004
%
%
% Smoothing batch file for SPM2
function batch_smooth(PAR, fidLog, DoSmoothing)

  % global PAR fidLog;

   if (exist('fidLog','var')==0) || (isempty(fidLog))
      fidLog = 1;
   end      
   if (exist('DoSmoothing','var')==0) || (isempty(DoSmoothing))
      DoSmoothing = true;
   end   

   if (fidLog<=0), fidLog=1; end  %if fidLog is not previously defined, set to 1 to send output to screen
   if DoSmoothing 
      fprintf(fidLog,'\n%s: Smoothing the realigned functional images\n', datestr(datetime('now')));
   else
      fprintf(fidLog,'\n%s: Will skip smoothing; will just copy the realigned functional images to the ''s'' filenames. \n', datestr(datetime('now')));
   end   
   %par;

   disp('Smoothing the realigned functional images, it is quick....');
   org_pwd=pwd;
   % dirnames,
   % get the subdirectories in the main directory
   for s = 1:PAR.nsubs % for each subject
      for c=1:PAR.ncond
         str   = sprintf('-- processing subject/condition: #%d/%d  (''%s''/''%s'')',s, c,PAR.subjects{s},PAR.sessionfilters{c} );
         fprintf(fidLog, '%s\n',str);

         %P=[];
         %dir_func = fullfile(PAR.root, PAR.subjects{s},PAR.sesses{ses},PAR.condirs{c});

         %TEMPORARY - create a smoothed version of the meanPASL image.  TF 18 Oct 2017
         P=spm_select('FPList', char(PAR.condirs{s,c}), ['^meanPASL'  '\w*\.nii$']);
         if (DoSmoothing) 
            ASLtbx_smoothing(P, PAR.FWHM);      
         else
            for i=1:size(P,1)
               [pth,nam,ext,num] = spm_fileparts(P(i,:));
               copyfile(P(i,:), fullfile(pth,['s' nam ext]));
            end;
         end;
         
         P=spm_select('FPList', char(PAR.M0dirs{s,c}), ['^r' PAR.M0filters{c} '\w*\.nii$']);
         if (DoSmoothing) 
            ASLtbx_smoothing(P, PAR.FWHM);      
         else
            for i=1:size(P,1)
               [pth,nam,ext,num] = spm_fileparts(P(i,:));
               copyfile(P(i,:), fullfile(pth,['s' nam ext]));
            end;
         end;

         fltimgs=spm_select('FPList', PAR.condirs{s,c}, ['^ASLflt_oe_r'  PAR.confilters{c}  '\.nii']);
         if isempty(fltimgs), fprintf('You didn''t selecte any images!\n'); return;end;
         if size(fltimgs,1)==1
            [pth,nam,ext,num] = spm_fileparts(fltimgs);
            fltimgs=fullfile(pth, [nam ext]);
         end
         [pth,nam,ext,num] = spm_fileparts(fltimgs(1,:));
         
         if (DoSmoothing) 
            ASLtbx_smoothing(fltimgs, PAR.FWHM);  
         else
            for i=1:size(fltimgs,1)
               [pth,nam,ext,num] = spm_fileparts(fltimgs(i,:));
               copyfile(fltimgs(i,:), fullfile(pth,['s' nam ext]));
            end;
         end;         
         
      end

   end
   cd(org_pwd);
   
end