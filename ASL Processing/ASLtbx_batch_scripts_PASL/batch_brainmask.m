% Toolbox for batch processing ASL perfusion based fMRI data.
% All rights reserved.
% Ze Wang @ TRC, CFN, Upenn 2004
%
%
% Smoothing batch file for SPM2
%
% Modified by Tod Flak 03-Aug-2020.  Enclosed as a function, added
% parameter to control whether using old simple threshold method
% (ASLtbx_createbrainmask) or the newer TPM-based method.

function batch_brainmask(Use_TPMForBrainMask) 
   global PAR fidLog;
   if (fidLog<=0), fidLog=1; end  %if fidLog is not previously defined, set to 1 to send output to screen
   if (exist('Use_TPMForBrainMask','var')==0) || (isempty(Use_TPMForBrainMask))
      Use_TPMForBrainMask = false;
   end      
   bool_vals=["false","true"];
   fprintf(fidLog,'\n%s: Creating brain mask, Use_TPMForBrainMask=%s\n', datestr(datetime('now')),bool_vals(Use_TPMForBrainMask+1));

   global defaults;
   defaults=spm_get_defaults;
   
   disp('Creating brain mask image ....');
   org_pwd=pwd;
   % dirnames,
   % get the subdirectories in the main directory
   for s = 1:PAR.nsubs % for each subject
      
      if (Use_TPMForBrainMask) 
         brainmask_structuralspace=fullfile(PAR.structdir{s}, 'brainmask_byTPM.nii' );  %will store this file in the structural folder, because it is same space as structural image & TPM's
         BrainMask_FromTPMs(PAR.structname{s},brainmask_structuralspace);
         fprintf(fidLog,'   Created brain mask in structural space, using TPM, filename:%s\n', brainmask_structuralspace);
      end
      
      for c=1:PAR.ncond
         str   = sprintf('-- processing subject/condition: #%d/%d  (''%s''/''%s'')',s, c,PAR.subjects{s},PAR.sessionfilters{c} );
         fprintf(fidLog, '%s\n',str);


         if (Use_TPMForBrainMask) 
            %resample brainmask created above into the space of the rM0 image
            %Note that this assume the rM0 image has already been
            %coregisted to the structural image
            reference_img=spm_select('FPList', PAR.condirs{s,c}, ['^r' PAR.M0filters{c} '\w*\.nii$']);
            P = strvcat(reference_img,brainmask_structuralspace);
            flags = defaults.coreg;
            resliceFlags = struct(...
               'interp', 1,...                       % trilinear interpolation
               'wrap', flags.write.wrap,...           % wrapping info (ignore...)
               'mask', flags.write.mask,...           % masking (see spm_reslice)
               'which',1,...                         % write reslice time series for later use, don't reslice the first image
               'mean',0);                            % don't create a mean image            
            spm_reslice_flt(P,resliceFlags);  %create the resliced image, filename will be rbrainmask_byTPM.nii
            brainmask_ASLspace = fullfile(PAR.structdir{s}, 'rbrainmask_byTPM.nii' ); 
            brainmaskfile = fullfile(PAR.condirs{s,c}, 'brainmask.nii' ); 
            movefile(brainmask_ASLspace,brainmaskfile);
            
         else  %the old way; use the mean ASL image and do a simple thresholding
            meanimg=spm_select('FPList', PAR.condirs{s,c}, ['^mean' PAR.confilters{c} '\w*\.nii$']);
            brainmaskfile = ASLtbx_createbrainmask(meanimg);
         end
         fprintf(fidLog,'   Created brain mask file: %s\n', brainmaskfile );    
      end
   end
end   