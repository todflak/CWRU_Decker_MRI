%Starting with a brain mask and a mean CBF map, create a new brain mask for the voxels
%where CBF is above a filter value.  This is the strategy suggested by Chris Flask.
%Tod Flak 18 Jan 2018
function CWRU_ASL_FilterMaskByCBF(MaskFile_Original, CBF_File, CBF_FilterLevel, MaskFile_New, fidLog)
   if (exist('fidLog','var')==0) || (isempty(fidLog))
      fidLog = 1;
   end      
   
   fprintf(fidLog,'%s: CWRU_ASL_FilterMaskByCBF, starting processing.\n', datestr(datetime('now')));
   fprintf(fidLog,'MaskFile_Original: %s\n', MaskFile_Original);
   fprintf(fidLog,'CBF_File: %s\n', CBF_File);   
   fprintf(fidLog,'CBF_FilterLevel: %f\n', CBF_FilterLevel);
      
   maskinfo = spm_vol(MaskFile_Original);
   maskdata_original = spm_read_vols(maskinfo);
   cbfdata = spm_read_vols(spm_vol(CBF_File));
   cbf_meetsfilter = (cbfdata>CBF_FilterLevel);
   maskdata_new = maskdata_original .* cbf_meetsfilter;
   maskinfo.fname = MaskFile_New;
   maskinfo=spm_write_vol(maskinfo, maskdata_new);
   
   fprintf(fidLog,'Created filtered mask, MaskFile_New: %s\n', maskinfo.fname );

end