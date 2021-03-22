%This script takes an input Nii and a text file.  The text file contains a
%column of the search value and a column of replacement value.  For each 
%line in the text file, looks for value matches in the Nii and replaces
%those with the replacement value.  Writes the result to a new Nii file.

%TextFile should be a tab-delimited file, with a header row.

%I created this to take a SVReg-produced label file, and replace each ROI
%with a specific floating point value.  This allows us to produce an Nii
%which depicts ROI-computed values.

% TF 19 Nov 2019

function NiiReplaceValues(SourceNii,TextFile,OutputNii, ColIndex_SearchValue, ColIndex_ReplacementValue, Source_0toNaN, New_NaNto0)

    if (exist('Source_0toNaN','var')==0) || (isempty(Source_0toNaN))
        Source_0toNaN = 1;
    end
    if (exist('New_NaNto0','var')==0) || (isempty(New_NaNto0))
        New_NaNto0 = 1;
    end    
    
    vol = spm_vol(SourceNii);
    data = spm_read_vols(vol, Source_0toNaN);  %Note: 'mask' param=1, forces 0 values to NaN
    
    lines = splitlines(fileread(TextFile));

    count_values = size(lines,1)-1;
    original_values = zeros(count_values,1);
    new_values = zeros(count_values,1);
    
    for value_index=1:count_values
        fields = split(lines(value_index+1),char(9));
        if (size(fields,1)>=max(ColIndex_SearchValue, ColIndex_ReplacementValue))
            original_values(value_index) = str2double(fields(ColIndex_SearchValue));
            new_values(value_index) = str2double(fields(ColIndex_ReplacementValue));
        end
    end

    data_new = my_changem(data, new_values, original_values);
    
    if (New_NaNto0) 
        data_new(isnan(data_new))=0;         %want to now change NaN to 0
    end
    
    vol_new = vol;
    vol_new.fname = OutputNii;
    vol_new.dt=[16 0];  %set to float
    VNew = spm_write_vol(vol_new,data_new);
end


function mapout = my_changem(mapout, newcode, oldcode)
%implement functionality of changem, which is in MatLab Mapping toolbox; I
%was previously using changem, but didn't feel like paying for another
%toolbox just for one simple function.  TF 21Mar2021
   assert(numel(newcode) == numel(oldcode), 'newcode and oldecode must have the same number of elements');
   [toreplace, bywhat] = ismember(mapout, oldcode);
   mapout(toreplace) = newcode(bywhat(toreplace));
end