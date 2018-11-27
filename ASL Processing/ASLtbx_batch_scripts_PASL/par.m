% Batch mode scripts for running spm5 in TRC
% Created by Ze Wang, 08-05-2004
% zewang@mail.med.upenn.edu

function P = par(Data_Root, Study_Folders_ToProcess )
   global PAR fidLog;
   if (exist('fidLog','var')==0) || isempty(fidLog)
      fidLog=1; %by default, output to screen
   end
   
   if ~isempty(PAR)
      fprintf('%s\n','PAR already set, so doing nothing')
      P = PAR;
      return
   end

   fprintf(fidLog, '\n%s\n',repmat(sprintf('-'),1,30));
   fprintf(fidLog, '%-40s\n','Set PAR');

   PAR=[];

   PAR.SPM_path=spm('Dir');
   addpath(PAR.SPM_path);

   % This file sets up various things specific to this
   % analysis, and stores them in the global variable PAR,
   % which is used by the other batch files.
   % You don't have to do it this way of course, I just
   % found it easier



   %%%%%%%%%%%%%%%%%%%%%
   %                   %
   %   GENERAL PREFS   %
   %                   %
   %%%%%%%%%%%%%%%%%%%%%%
   % Where the subjects' data directories are stored

   PAR.batchcode_which= mfilename('fullpath');
   PAR.batchcode_which=fileparts(PAR.batchcode_which);
   addpath(PAR.batchcode_which);
   old_pwd=pwd;
   if ~exist('Data_Root','var') || isempty(Data_Root)
      cd(PAR.batchcode_which);
      cd ../
      Data_Root= uigetdir(pwd,'Select base data folder that contains subjects');
      cd(old_pwd);
   end

   PAR.root=Data_Root;
   PAR.datasubfolder = 'ASL';

   % Get subjects' directories
   % User
   if exist('Study_Folders_ToProcess','var') && (~isempty(Study_Folders_ToProcess))
      for idx=1:size(Study_Folders_ToProcess,1)
         PAR.subjects{idx} = deblank(Study_Folders_ToProcess(idx,:));
      end
   else
      FolderList_filename = fullfile(PAR.root, 'ASL_ToProcess.txt');
      PAR.subjects = {};
      fid = fopen(FolderList_filename);
      tline = fgetl(fid);
      idx = 0;
      while ischar(tline)
         tline = strtrim(tline);
         if (~strcmp(tline,'') )
            idx = idx+1;
            PAR.subjects{idx} = tline;
         end
         tline = fgetl(fid);
      end
      fclose(fid);
   end

   PAR.nsubs = length(PAR.subjects);
   
   fprintf(fidLog, 'Subject folders to be processed: \n');
   for idx=1:PAR.nsubs
      fprintf(fidLog,'%s\n', char(PAR.subjects(idx)));
   end   
   fprintf(fidLog,'\n');
      


   % Anatomical directory name
   PAR.structfilter='mprage';

   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   % Get the anatomical image directories automatically
   for sb=1:PAR.nsubs
      tmp=dir(fullfile(PAR.root,PAR.subjects{sb},PAR.datasubfolder,['*' PAR.structfilter '*']));
      tmp  = tmp(cellfun(@(x) x==1,{tmp.isdir}));  %select only directory entries
      if size(tmp,1)==0
         error('Can not find the anatomical directory for subject: %s\n', char(PAR.subjects{sb}));
      end
      if size(tmp,1)>1
         error('More than 1 anatomical directories for subject: %s are found here!\n',char(PAR.subjects{sb}))
      end
  %    PAR.structdir{sb}=fullfile(tmp(1).folder, tmp(1).name);
  %when changed to MatLab2015b, if only one subfolder found, tmp is not an
  %array!! Also, dir() does not return folder property!  TF 16 Nov 2017
      PAR.structdir{sb}=fullfile(PAR.root,PAR.subjects{sb},PAR.datasubfolder, tmp.name);

      %decided that I want to actually store the complete path to structure
      %image now.  TF 31 July 2017
      tmp=dir(fullfile(PAR.structdir{sb}, 's_mprage.nii' ));
      if size(tmp,1)~=1
         error('Failed to find structural file ''s_mprage.nii'' for subject "%s" ', char(PAR.subjects{sb}) );
      end
  %when changed to MatLab2015b, if only one subfolder found, tmp is not an
  %array!! Also, dir() does not return folder property!  TF 16 Nov 2017
  %    PAR.structname{sb} = fullfile(tmp(1).folder, tmp(1).name);
      PAR.structname{sb} = fullfile(PAR.structdir{sb}, tmp.name);
   end

   %prefixes for filenames of structural 3D images, supposed to be the same for every subj.
   PAR.structprefs = 's';
   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   % Getting condition directories

   %Note that this ASLtbx code was written with the assumption that there
   %would be the same condition directories for each subject.  This may not
   %always be the case for our studies.  I'm sure I could re-write the
   %structures and looping to allow for different condition directories for
   %each subject, but that is more work than I want to do now.  Instead,
   %the caller should ensure that all the subjects being analyzed all have
   %the same condition directories; or just process one subject as a time.
   %TF 23 Aug 2017


   % The condition names are assumed same for different sessions

   for sb=1:PAR.nsubs
      dirlisting = dir(fullfile(PAR.root,PAR.subjects{sb},PAR.datasubfolder));
      condition_index =0;
      for i=1:size(dirlisting,1)
         if (dirlisting(i).isdir)
            asl_foldername = regexp(dirlisting(i).name,'^asl.+$','match','once');
            if ~isempty(asl_foldername)
               condition_index = condition_index+1;
               if (sb==1) %for first subject, set the values in the PAR arrays
                  PAR.sessionfilters{condition_index} = dirlisting(i).name;
                  PAR.confilters{condition_index} = 'PASL'; %filters for finding the ASL images
                  PAR.M0filters{condition_index} = 'M0'; %filters for finding the M0 images
               else  %for additional subjects, just confirm that the folders match
                  if (condition_index>size(PAR.sessionfilters))
                     error('For subject index %d has more asl condition folders than the first subject has.\n', sb);
                  elseif ~strcmpi(PAR.sessionfilters{condition_index},dirlisting(i).name)
                     error('The ASL condition folders for subject index %d do not match the folders of the first subject.\n', sb);
                  end
               end
            end
         end
      end

      if (sb==1)  % for subject 1, set the other things necessary
         PAR.sessionM0filters = PAR.sessionfilters;
         PAR.ncond=length(PAR.sessionfilters);
         fprintf(fidLog,'Found %d condition folders:\n', PAR.ncond);   
		 for idx=1:PAR.ncond
		   fprintf(fidLog,'   ...\\%s\n', char(PAR.sessionfilters(idx)));
         end   
      end


      for c=1:PAR.ncond
%          tmp=dir(fullfile(PAR.root,PAR.subjects{sb},PAR.datasubfolder,['*' PAR.sessionfilters{c} '*']));
%          tmp  = tmp(cellfun(@(x) x==1,{tmp.isdir}));  %select only directory entries
%          if size(tmp,1)==0
%             error('Can not find the condition directory "%s" for subject "%s"', PAR.sessionfilters{c},  char(PAR.subjects{sb}));
%          end
% 
%          if size(tmp,1)>1
%             error('Panic! subject %s has more than 1 directories matching filter "%s*"', PAR.subjects{sb}, PAR.sessionfilters{c} );
%          end
%          %PAR.condirs{sb,c}=fullfile(PAR.root,PAR.subjects{sb},PAR.datasubfolder,spm_str_manip(char(tmp(1).name),'d'));
%          PAR.condirs{sb,c}=fullfile(tmp(1).folder, tmp(1).name);

% 
%          tmp=dir(fullfile(PAR.root,PAR.subjects{sb},PAR.datasubfolder,['*' PAR.sessionM0filters{c} '*' ]));
%          tmp  = tmp(cellfun(@(x) x==1,{tmp.isdir}));  %select only directory entries
%          if size(tmp,1)==0
%             error('Can not find the M0 directory for subject %s', char(PAR.subjects{sb}));
%          end
% 
%          if size(tmp,1)>1
%             sprintf('Panic! subject %s has more than 1 M0 directories!\n', [PAR.subjects{sb}])
%             error('Panic! condition has more than 1 M0 directories!')
%             %return;
%          end
% 
%          %PAR.M0dirs{sb,c}=fullfile(PAR.root,PAR.subjects{sb},PAR.datasubfolder,spm_str_manip(char(tmp(1).name),'d'));
%          PAR.M0dirs{sb,c}=fullfile(tmp(1).folder, tmp(1).name);
%          
         
% No need to search again for the ASL subfolders, so just assign the value.
%  TF 02 Oct 2017
         PAR.condirs{sb,c}=fullfile(PAR.root,PAR.subjects{sb},PAR.datasubfolder, PAR.sessionfilters{c} );
         PAR.M0dirs{sb,c}=fullfile(PAR.root,PAR.subjects{sb},PAR.datasubfolder, PAR.sessionfilters{c} );
      end
   end

   % Smoothing kernel size
   PAR.FWHM = [6];

   % % TR for each subject.  As one experiment was carried out in one Hospital (with one machine)
   % % and the other in another hospital (different machine), TRs are slightly different
   % %PAR.TRs = [2.4696 2];
   PAR.TRs = ones(1,PAR.nsubs)*6;
   % PAR.mp='no';

   %
   PAR.mp='no';
   %
   PAR.groupdir = ['group_anasmallPerf_sinc'];

   %contrast names
   PAR.con_names={'tap_rest'};


   PAR.subtractiontype=0;
   PAR.glcbffile=['globalsg_' num2str(PAR.subtractiontype) '.txt'];
   PAR.img4analysis='cbf'; % or 'Perf'
   PAR.ana_dir = ['glm_' PAR.img4analysis];
   PAR.Filter='cbf_0_sr';

   P = PAR;
end

