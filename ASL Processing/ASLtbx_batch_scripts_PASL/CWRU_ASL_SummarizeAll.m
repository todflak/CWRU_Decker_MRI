%Perform numeric summarization for all ASLs in current study group.


%Data_Root (char vector) must be path to data folder inside of which are
%session folders.

%Study_Folders_ToProcess should be a array of char vector.  For a single
% session folder, you can use syntax %like ['subject1']; for multiple
% folders, use the char function, such as char('subject1', 'subject2')
%If Study_Folders_ToProcess is empty will use the spm_select function

% LabelDescriptionMatLabFile must point to a ".mat" file that defines one
% table variable named 'SVRegLabelDescription' which contains the following 
% columns: LabelValue, Label, Tag

%If LogFilename (char vector) is not specified, output will go to screen.
%If ExcelFilename is specified, output will go into new sheets in the Excel
%file.  If not specified, output will go into text files in the ASL
%folders.

%An example call:
% CWRU_ASL_SummarizeAll('C:\Users\Tod\Documents\BioAutomatix\Clients\Decker\MRI Processing\Example data\Chronic Fatigue', ['WM\WM_post'], 'C:\Users\Tod\Documents\BioAutomatix\Clients\Decker\MRI Processing\Example data\Chronic Fatigue\WM\WM_post\ASL_Summarize_Log.txt')

function CWRU_ASL_SummarizeAll(Data_Root, Study_Folders_ToProcess, LabelDescriptionMatLabFile, LogFilename, ExcelFilename) 
   clear global PAR
   
   global fidLog
   fidLog=1;  %default to standard out
   if exist('LogFilename','var') && (~isempty(LogFilename))
      fidLog = fopen(LogFilename, 'a');  %open for append
   end

   fprintf(fidLog,'%s: CWRU_ASL_SummarizeAll, starting processing.\n', datestr(datetime('now')));
   fprintf(fidLog,'Data_Root:%s\n', Data_Root);
   fprintf(fidLog,'Study_Folders_ToProcess:\n%s\n', char(Study_Folders_ToProcess));
   fprintf(fidLog,'LabelDescriptionMatLabFile:%s\n', LabelDescriptionMatLabFile);

   OutputToExcel = true;
   if ~exist('ExcelFilename','var') || isempty(ExcelFilename)
      %ExcelFilename = fullfile(PAR.root, 'ASL_Summarization.xlsm');
      OutputToExcel = false;
      fprintf(fidLog,'ExcelFilename is empty, so output will be to text files.\n');
   else
      fprintf(fidLog,'ExcelFilename: %s\n', ExcelFilename);
   end
   fprintf(fidLog,'\n');   
   
   try
      %set the parameters
      PAR=[];  %make sure it is cleared so will be rebuilt
      PAR = par(Data_Root, Study_Folders_ToProcess);

      %Produce the resliced files
      %Before we do that, for each subject, look for a Brainsuite folder,
      %search for '*svreg.label.nii' which we should change into non-rotated 
      % space 
      for s=1:PAR.nsubs
         %find the SVreg label file\
         bs_folder = fullfile(PAR.root, PAR.subjects{s}, 'BrainSuite');
         svreg_filefilter = fullfile(bs_folder,'*svreg.label.nii');
         tmp = dir(svreg_filefilter);
         if (size(tmp,1)==0)
            %look for a "gz" version of the same.
            svreg_filefilter = fullfile(bs_folder,'*svreg.label.nii.gz');
            tmp = dir(svreg_filefilter);
            if (size(tmp,1)==1)
              %svreg_filefilter = gunzip(fullfile(tmp(1).folder, tmp(1).name));
              %when changed to MatLab2015b, dir() does not return folder property!  TF 16 Nov 2017

               svreg_filefilter = gunzip(fullfile(bs_folder, tmp(1).name));
               svreg_filefilter = char(svreg_filefilter);
               tmp = dir(svreg_filefilter);
            else
               fprintf(fidLog,'For subject ''%s'', could not find SVReg label file, using pattern: %s', PAR.subjects{s}, svreg_filefilter);
               svreg_filefilter = fullfile(bs_folder,'*svreg.label.nii');  %go back to original filter to print into the error message below
            end
         end
         
         if (size(tmp,1)==0)
            error('For subject ''%s'', could not find SVReg label file, using pattern: %s', PAR.subjects{s}, svreg_filefilter);
         end
         
         if (size(tmp,1)>1)
            error('For subject ''%s'', found multiple SVReg label files, using pattern: %s', PAR.subjects{s}, svreg_filefilter);
         end
         PAR.NII_AdditionalFiles_NoRotate{s} = fullfile(bs_folder, tmp(1).name);
      end
      
      CWRU_ASL_SliceIntoNoRotationSpace(PAR, true);   

      %filename_tabLabels =  fullfile(PAR.root, 'SVREG_LabelDescription_BrainSuiteAtlas1.mat');
      filename_tabLabels = LabelDescriptionMatLabFile;
      load(filename_tabLabels);

      fprintf(fidLog,'\n%s: CWRU_ASL_SummarizeAll, starting summarization.\n', datestr(datetime('now')));
      for s=1:PAR.nsubs
         %find the SVreg label file
         bs_folder = fullfile(PAR.root, PAR.subjects{s}, 'BrainSuite');
         svreg_filefilter = fullfile(bs_folder,'*svreg.label_norot.nii');
         tmp = dir(svreg_filefilter);
         if (size(tmp,1)~=1)
            error('For subject ''%s'', could not find SVReg label file, using pattern: %s', PAR.subjects{s}, svreg_filefilter);
         end
         filename_SVRegLabels = fullfile(bs_folder, tmp(1).name);

         %for the ASL data, get ready to transform the files.
         %  ASL_FileToProcess_Filter = {'meanCBF_*rPASL.nii'; 'meanPERF_*rPASL.nii'};
         ASL_FileToProcess_Filter = {'meanCBF_0_sASLflt_oe_rPASL.nii'};   % changed by TF 07 June 2018, to avoid getting incorrect files.
		 
         for c=1:PAR.ncond
            str   = sprintf('-- processing subject/condition: #%d/%d  (''%s''/''%s'')',s, c,PAR.subjects{s},PAR.sessionfilters{c} );
            fprintf(fidLog, '%s\n',str);

            for filt=1:size(ASL_FileToProcess_Filter,1)
               ASL_files = dir(fullfile(PAR.condirs{c}, ASL_FileToProcess_Filter{filt}));
               for f = 1:size(ASL_files,1)
                  niiFilename_ASL = ASL_files(f);
               %   niiFilename_ASL = fullfile(niiFilename_ASL.folder, niiFilename_ASL.name);
              %when changed to MatLab2015b, dir() does not return folder property!  TF 16 Nov 2017
                  niiFilename_ASL = fullfile(PAR.condirs{c}, niiFilename_ASL.name);
                  %prepare the new filenames we need
                  [pth,nam,ext,num] = spm_fileparts(niiFilename_ASL);
                  niiFilename_ASL_Resized  = [fullfile(pth, nam) '_resized' ext]; 

                  %now we can produce the summarization
                  tabSummarization = CWRU_ASL_Summarize_PerBrainSegment( ...
                     niiFilename_ASL_Resized, ...
                     filename_SVRegLabels, SVRegLabelDescription); 

                  [pth,nam,ext,num] = spm_fileparts(niiFilename_ASL_Resized);
                  nameparts = strsplit(nam,'_');
                  if OutputToExcel 
                     sheetname = char(strcat(PAR.subjects{s},'-', PAR.sessionfilters{c},'-', nameparts(1))); %take the name part up to the first underscore
                     if size(sheetname,2)>31  %max sheet name is 31 chars
                        sheetname = sheetname(1:31);
                     end
                     writetable(tabSummarization,ExcelFilename,'Sheet',sheetname);
                     fprintf(fidLog, 'For subject/condition: #%d/%d,  wrote summarization data to worksheet name ''%s''\n',s,c,sheetname);

                  else %if not OutputToExcel, then output to a text file
                     TextFilename = fullfile(pth,[char(nameparts(1)) '_ROI_Summary' '.txt' ]);
                     writetable(tabSummarization,TextFilename,'FileType','text','Delimiter','tab');
                     fprintf(fidLog, 'For subject/condition: #%d/%d, wrote summarization data to filename ''%s''\n',s,c,TextFilename);
                  end
               end
            end
         end
      end
      fprintf(fidLog,'%s: CWRU_ASL_SummarizeAll, processing complete.\n', datestr(datetime('now')));
      
   catch ex
      fprintf(fidLog,'\nProcessing Error: %s.\n', ex.message);
      fprintf(fidLog,'Stack trace:\n');
      for k=1:length(ex.stack)
         fprintf(fidLog,'% *d: %s, line %d\n', k+1, k, ex.stack(k).name, ex.stack(k).line);
      end      
   end
   
   if (fidLog>=3)
      fclose(fidLog);
   end
end