% If you have already computed tissue probabiliy maps, you can use this to
% compute a brain mask file.  This relies on the grey matter and white
% matter TPMs (c1 and c2); it dilates a little bitand then fills in any
% holes (completely enclosed volumes).  There are some hard-coded values,
% such as the threshold of the probability map, the dilation amount, and
% the value to produce in the final mask file.  These could be exposed as
% optional function params if there is ever a need change the values.
% Tod Flak 12 April 2018
%
% TPM_BaseFilename is the complete path to the starting structural image
% used to produce the TPMs.  The resulting TPMs must be in the same folder,
% and be prefixed by "c1", "c2", etc.

function BrainMask_FromTPMs(TPM_BaseFilename, OutputMaskFileName)

    [pth,base_name,ext,~] = spm_fileparts(TPM_BaseFilename); 
    vol_base = spm_vol(TPM_BaseFilename);
    mask_image = zeros(vol_base.dim,'uint8');
    tpm_threshold = 0.25;
    
    for tpm_index = 1:2
        tpm_filename = fullfile(pth,['c' sprintf('%i',tpm_index) base_name ext]);
        this_img = spm_read_vols(spm_vol(tpm_filename));
        mask_image = mask_image + uint8(this_img>tpm_threshold);
    end
    
    %dilate a bit
    se = strel('diamond',4);
    mask_image = imdilate(mask_image,se);
    %fill in completely enclosed holes
    mask_image = imfill(mask_image,'holes');
    mask_image = imdilate(mask_image,se);  %do a bit more to fill in remaining internal holes (maybe with small channel to outside)
    mask_image = imfill(mask_image,'holes');
    mask_image = imerode(mask_image,se);
    mask_image(mask_image>0) = 255;
    
    DoGZip = false;
    [pth,base_name,ext,~] = spm_fileparts(OutputMaskFileName); 
    if strcmpi(ext,'.gz')
        DoGZip = true;
        OutputMaskFileName = fullfile(pth,base_name);
    end
    
    vol_base.fname = OutputMaskFileName;
    vol_base.dt = [spm_type('uint8') 0];
    spm_write_vol(vol_base, mask_image);

    if DoGZip
        gzip(OutputMaskFileName);
        delete(OutputMaskFileName);
    end
end