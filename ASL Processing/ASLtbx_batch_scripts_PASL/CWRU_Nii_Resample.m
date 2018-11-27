%CWRU_Nii_Resample
%From the given Nii, create a new Nii with the same resolution and orientation
%as the TargetImagespaceFilename data.  

%Returns value is the struct array (from spm_vol) containing information on output image.
%  See spm_vol

function V_resized= CWRU_Nii_Resample(SourceImageFilename, TargetImagespaceFilename, NewImageFilename)
   %The trick here is to use spm_imcalc, simply setting the reference image (the first 
   % image) to be an array of 0's in the same space as the TargetImagespaceFilename data,
   % and then adding the SourceImageFilename.  This will apply 
   % interpolation and reorientation to bring the data into alignment with the TargetImagespaceFilename.

   Vzero = spm_vol(TargetImagespaceFilename);  %get the information about the target imagespace
   [pth nam ext num] = spm_fileparts(SourceImageFilename);
   %img = spm_read_vols(Vzero_PASL);   
   
   %create a zero image
   Vzero.fname = fullfile(pth, 'tmp_zeroes.nii');
   Vzero.dt = [spm_type('float32') 0];
   Vzero = spm_write_vol(Vzero, zeros(Vzero.dim(1:3)));
   VSource = spm_vol(SourceImageFilename);
   Vi = [Vzero  VSource];
   V_resized= Vzero;  %copy the structure from the PASL data
   V_resized.fname=NewImageFilename;

   %flags for spm_imcalc
   dmtx=0;  %do not use data matrix
   mask=0;  %do not use mask values
   interp=1; %interp=1 is trilinear;
   dtype = spm_type('float32');
   V_resized = spm_imcalc(Vi, V_resized, 'i1 + i2', {dmtx,mask,interp,dtype} );

   delete(Vzero.fname);
end