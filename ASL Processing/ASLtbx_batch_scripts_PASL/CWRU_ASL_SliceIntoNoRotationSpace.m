% Resample the ASL perfusion and CBF images to put them into the same space
% as the structural images and SVReg info.
% Caller must pass the PAR structure used in ASL computation.
% If desired, caller can add one parameter to the PAR structure, a vector
% called NII_AdditionalFiles_NoRotate.  If present will also create a 
% non-rotated version of those files.

% Will first produce a non-rotated version of the structural file, with
% suffix "_norot"
% Will then produce a non-rotated version of the files in the list 
%   NII_AdditionalFiles_NoRotate, with suffix "_norot"

% Will then produce a rotated version of all ASL meanCBF and meanPERF
% files, to match the non-rotated structural space with suffix "_rot2struct.nii"
% Then performs a reslice, to resample the ASL data with the same voxel
% size as the structural image.  This process also removes the q-form and
% s-form rotations, so the data is in the same space as the structural
% image (although still with a translation), with suffix '_reslice'
%Finally, pad/clip the resliced images so that they have the same voxel
%dimensions as the structural image; with suffix '_resize'


%TODO: should be possible to change the translations of structural image
%and rotated ASL images, such that when we reslice the voxels line up so 
% that the padding/clipping does not need fractional voxels

function CWRU_ASL_SliceIntoNoRotationSpace(par, remove_intermediate_files) 
   global fidLog;
   if (exist('fidLog','var')==0) || isempty(fidLog)
      fidLog=1; %by default, output to screen
   end
  
   for s=1:par.nsubs
      str = sprintf('\n%s: CWRU_ASL_SliceIntoNoRotationSpace, producing non-rotated files for subject: %s', datestr(datetime('now')), par.subjects{s});
      disp(str);
      fprintf(fidLog,'%s\n',str);
      
      niiFilename_structural = par.structname{s};
      [q_structural, t_structural] = CWRU_Nii_load_rotation(niiFilename_structural,'q-form');

      %first produce un-rotated versions of the structural and label files.
      %This is done simply by rotating by the inverse quaternion of their
      %current rotation.  This will produce files where the q-form and s-form
      %transforms are no rotation (but perserving the proper center point)
      [pth,nam,ext,num] = spm_fileparts(niiFilename_structural);
      niiFilename_structural_NoRotate = [fullfile(pth, nam) '_norot' ext];
      CWRU_RotateNii(niiFilename_structural, q_structural.inverse, niiFilename_structural_NoRotate);
      fprintf(fidLog,'Produced non-rotated anatomical image: %s\n',niiFilename_structural_NoRotate);
      
      %do the same for any other files in the vector par.NII_AdditionalFiles_NoRotate
      if isfield(par,'NII_AdditionalFiles_NoRotate')
         for i=1:size(par.NII_AdditionalFiles_NoRotate,1)
            niiFilename = par.NII_AdditionalFiles_NoRotate{i};
            [pth,nam,ext,num] = spm_fileparts(niiFilename);
            niiFilename_NoRotate = [fullfile(pth, nam) '_norot' ext];
            CWRU_RotateNii(niiFilename, q_structural.inverse, niiFilename_NoRotate);
            fprintf(fidLog,'Produced non-rotated other image: %s\n',niiFilename_NoRotate);
         end
      end
      
      %for the ASL data, get ready to transform the files.
    %  ASL_FileToProcess_Filter = {'meanCBF_*rPASL.nii'; 'meanPERF_*rPASL.nii'; 'brainmask.nii'};
      ASL_FileToProcess_Filter = {'meanCBF_0_sASLflt_oe_rPASL.nii'; 'brainmask.nii'};  %changed by TF 07 June 2018.  Now using '_oe_' version (outlier-excluded); and decided it was not necessary to do teh Perfusion image
          
      for c=1:par.ncond

         for filt=1:size(ASL_FileToProcess_Filter,1)
            ASL_files = dir(fullfile(par.condirs{c}, ASL_FileToProcess_Filter{filt}));
            for f = 1:size(ASL_files,1)
               niiFilename_ASL = ASL_files(f);
               %niiFilename_ASL = fullfile(niiFilename_ASL.folder, niiFilename_ASL.name);
         %when changed to MatLab2015b, dir() does not return folder property!  TF 16 Nov 2017
               niiFilename_ASL = fullfile(par.condirs{c}, niiFilename_ASL.name);
               %prepare the new filenames we need
               [pth,nam,ext,num] = spm_fileparts(niiFilename_ASL);
               niiFilename_ASL_Rotate2Structural = [fullfile(pth, nam) '_rot2struct' ext];    
               niiFilename_ASL_Resliced = [fullfile(pth, nam) '_reslice' ext];   
               niiFilename_ASL_Resized  = [fullfile(pth, nam) '_resized' ext]; 
                              
               %now apply that same rotation to the ASL data.  This produces a non-zero
               %rotation to overlay onto the un-rotated structural image

               CWRU_RotateNii(niiFilename_ASL, q_structural.inverse, niiFilename_ASL_Rotate2Structural);
               if ~remove_intermediate_files 
                  fprintf(fidLog,'Produced ASL file rotated to structural image: %s\n',niiFilename_ASL_Rotate2Structural);
               end
               %if you now use Mango to overlay the niiFilename_ASL_NoRotate onto the 
               % niiFilename_structural_NoRotate, there should be the same perfect
               % correspondence as it was when we started.
               % However, the ASL data is being projected by its rotation matrix into
               % the structural space.  
               % Now we want to reslice the ASL data to recompute the data in that
               % structural space.  Only in that way can we have the matrices overlap
               % correctly, which will make our summarization work much easier

               nii_structural_norotate = load_nii(niiFilename_structural_NoRotate);
               hdr_structural= nii_structural_norotate.hdr;
               voxelsize_structural = hdr_structural.dime.pixdim(2:4);
               reslice_nii(niiFilename_ASL_Rotate2Structural,niiFilename_ASL_Resliced,  ...
                   voxelsize_structural, 0, 0, 1);
               if ~remove_intermediate_files  
                  fprintf(fidLog,'Produced ASL file reliced to remove rotation to match structural image: %s\n',niiFilename_ASL_Resliced);
               end
               
               %now make the resliced ASL image the same size, in voxels, so that the
               %matrices can be directly compared
               niiResliced = load_nii(niiFilename_ASL_Resliced);
               niiResized = CWRU_nii_MatchSize(niiResliced, hdr_structural);
               save_nii(niiResized,niiFilename_ASL_Resized);
               fprintf(fidLog,'Produced ASL data resliced and non-rotated, and resized to match structural image: %s\n',niiFilename_ASL_Resized);
              
               if ~isempty(remove_intermediate_files)
                  if remove_intermediate_files 
                     delete(niiFilename_ASL_Rotate2Structural);
                     delete(niiFilename_ASL_Resliced);
                  end
               end
            end
         end
      end
   end
end