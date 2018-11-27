% Performs numeric summarization of the data values in one 3D NII, based 
% upon the brain segments as defined in a "label" NII file, such as that
% produced by SVReg.

% The numeric summarizations performed are: mean, stdev, count, volume
% The nii_labels should be an image with discrete numeric values that
% indicate different brain segments.  

% tabLabels (optional): The parameter tabLabels should be a Matlab table
% object that defines the label codes; it should contain these fields:
% LabelValue, Label, Tag.   If this table is supplied, these fields will be
% placed into the output table; if not supplied, the those columns will be
% missing from the table

% The return value is a Matlab Table, containing these fields: 
% LabelValue, [Label], [Tag], Mean, Mean_StDev, Count_Voxels, Volume_mm3

% Tod Flak 26 July 2017

function T = CWRU_ASL_Summarize_PerBrainSegment(niiData_filename, ...
   niiLabels_filename, tabLabels) 
   global fidLog
   if (exist('fidLog','var')==0) || isempty(fidLog)
      fidLog=1; %by default, output to screen
   end
   
   blnUseTabLabels = true;
   if ~exist('tabLabels','var') || isempty(tabLabels)
      blnUseTabLabels = false;
   end

   T = table;
   niiLabels = load_untouch_nii(niiLabels_filename);
   niiData = load_untouch_nii(niiData_filename);
   
   arrLabel_All = niiLabels.img;
   labelIDs_distinct = unique(arrLabel_All);
   voxelsize_mm3 = prod(niiData.hdr.dime.pixdim(2:4));
   
   for idxLabelID=1:size(labelIDs_distinct,1)
      intLabelID = labelIDs_distinct(idxLabelID);  %get the label ID
      arrLabel_ThisID = (arrLabel_All==intLabelID); %find the cells in the label image matrix that are of this value...this is a boolean matrix
      vecDataElements_ThisID = niiData.img(arrLabel_ThisID);  %find the cells in the data image matrix that are at the indices of the boolean selection matrix
      
      %assemble all the data we need to add a row to the output table
      ROI_ID =intLabelID;
      Mean = mean(vecDataElements_ThisID);
      Mean_StDev = std(vecDataElements_ThisID);
      Count_Voxels = size(vecDataElements_ThisID,1);
      Volume_mm3 = size(vecDataElements_ThisID,1) * voxelsize_mm3;
      
      if (blnUseTabLabels)
         tabLabels_ThisID = tabLabels(tabLabels.LabelValue==intLabelID,:);  %get the table row having this LabelID
         if size(tabLabels_ThisID,1)>0 
            Label = tabLabels_ThisID{1,{'Label'}};
            Tag = tabLabels_ThisID{1,{'Tag'}};     
         else
            Label = {'<not found>'};
            Tag = {'<not found>'};
         end
         T = [T ; table(ROI_ID, Label, Tag, Mean, Mean_StDev, Count_Voxels, Volume_mm3)];

      else
         T = [T ; table(ROI_ID, Mean, Mean_StDev, Count_Voxels, Volume_mm3)];
      end
   end
   
   return;
end

