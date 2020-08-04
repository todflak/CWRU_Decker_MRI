% Using the multi-PLD delay pCASL sequence,all images are together in one
% Nii.  This script extracts into separate Nii files, with the M0 image at
% the front of each of them. 
% 
% Params:
%   sourceNii: full path to source Nii 
%   CountPairs: vector telling how many image pairs are in each PLD group

function CWRU_pCASL_multidelay_extract(sourceNii, CountPairs) 
   if ~exist('sourceNii','var') || isempty(sourceNii)
      sourceNii = spm_select;
   end

   for i = 1:size(sourceNii,1)
      nii_input_filename = sourceNii(i,:);
      fprintf('Processing NII file: %s \n', nii_input_filename);

      delete_uncompressed_Nii=false;
      nii_filename_toprocess = nii_input_filename;
      [pth,nam,ext,num] = spm_fileparts(nii_input_filename);
      if (strcmp(lower(ext),'.gz'))
         delete_uncompressed_Nii=true;
         nii_filename_toprocess = gunzip(nii_input_filename);
         nii_filename_toprocess = nii_filename_toprocess{1};
      end
      

%   FORMAT str = spm_file(str,opt_key,opt_val,...)
%   str        - character array, or cell array of strings
%   opt_key    - string of targeted item - one among:
%                {'path', 'basename', 'ext', 'filename', 'number', 'prefix',
%                'suffix','link','local'}
%   opt_val    - string of new value for feature
  
      hdrs=spm_vol(nii_filename_toprocess);
      if ((rem(size(hdrs,1),2)==1) || (size(hdrs,1)<4) )
          fprintf('The NII should have an even number of images, and be >=4; for image file %i, selected file contains %i images \n', i, size(hdrs,1) );
          return;
      end

      pld_img_first = 3; %assume first image in first PLD group is #3 (#1 is M0, #2 is discarded partner of M0)
      for pld_idx=1:size(CountPairs,2)
         pld_suffix = sprintf('_PLD_%i',pld_idx);
         pld_filename=spm_file(nii_filename_toprocess,'suffix',pld_suffix);
         
         pld_img_last = pld_img_first + CountPairs(pld_idx)*2 -1 ;
         img_idx= pld_img_first:pld_img_last; %select images we want in this PLD group
         img_idx=[1 img_idx];  %add in the M0 image
         spm_file_merge(hdrs(img_idx),pld_filename,0);
         
         pld_img_first = pld_img_last + 1; %for next PLD group
      end
         
      if (delete_uncompressed_Nii) 
         delete(nii_filename_toprocess)
      end
      
     % fprintf('Produced M0.nii and ASL.nii from input file: "%s"\n', nii_input_filename);

   end


end
