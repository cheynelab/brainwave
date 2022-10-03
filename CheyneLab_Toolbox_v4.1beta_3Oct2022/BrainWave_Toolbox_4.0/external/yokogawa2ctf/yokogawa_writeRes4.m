function err=writeRes4(res4File,res4,MAX_COILS)
%  Write the new .res4 file.  Use ieee-be (big endian) format
%  Character-string output is done using function writeCTFstring which
%  checks that strings are the correct length for the .res4 file format.
%
%  Function calls: - writeCTFstring (included in this listing).
%
% Modified by M. Woodbury from CTF version for Yokogawa datasets
%  
fid_res4=fopen(res4File,'w','b');
if fid_res4<0
  fprintf('writeRes4: Could not open file %s\n',res4File);
  err = -1;
  return
end

fwrite(fid_res4,[res4.header(1:7),char(0)],'uint8');   % 8-byte header

%  meg41GeneralResRec
res4.appName=writeCTFstring(res4.appName,-256,fid_res4);
res4.dataOrigin=writeCTFstring(res4.dataOrigin,-256,fid_res4);
res4.dataDescription=writeCTFstring(res4.dataDescription,-256,fid_res4);
fwrite(fid_res4,res4.no_trials_avgd,'int16');
res4.data_time=writeCTFstring(res4.data_time,255,fid_res4);
res4.data_date=writeCTFstring(res4.data_date,255,fid_res4);

% new_general_setup_rec_ext part of meg41GeneralResRec

fwrite(fid_res4,res4.no_samples,'int32');        % 4
fwrite(fid_res4,[res4.no_channels 0],'int16');   % 2*2
fwrite(fid_res4,res4.sample_rate,'double');      % 8
fwrite(fid_res4,res4.epoch_time,'double');       % 8
fwrite(fid_res4,[res4.no_trials 0],'int16');     % 2*2
fwrite(fid_res4,res4.preTrigPts,'int32');        % 4
fwrite(fid_res4,res4.no_trials_done,'int16');    % 2
fwrite(fid_res4,res4.no_trials_display,'int16'); % 2
fwrite(fid_res4,res4.save_trials,'int32');       % 4 CTFBoolean

% meg41TriggerData part of new_general_setup_rec_ext   10 bytes total
fwrite(fid_res4,res4.primaryTrigger,'uchar');      % 1
fwrite(fid_res4,res4.secondaryTrigger,'uchar');    % 1
fwrite(fid_res4,res4.triggerPolarityMask,'uchar'); % 1
fwrite(fid_res4,[0 0],'uint8');                    % 2 bytes
% end of meg41TriggerData part of new_general_setup_rec_ext

fwrite(fid_res4,res4.trigger_mode,'int16');    % 2
fwrite(fid_res4,0,'uchar');                    % 1
fwrite(fid_res4,res4.accept_reject_Flag,'int32');  % 4 CTFBoolean
fwrite(fid_res4,[res4.run_time_display 0],'int16');% 2*2

fwrite(fid_res4,res4.zero_Head_Flag,'int32');      % 4 CTFBoolean
fwrite(fid_res4,res4.artifact_mode,'int32');       % 4 CTFBoolean
%  end of new_general_setup_rec_ext part of meg41GeneralResRec

fwrite(fid_res4,[0 0],'int32');                   % 8 bytes (makes up rest of new_general_setup_rec_ext size

% meg4FileSetup part of meg41GeneralResRec
res4.nf_run_name=writeCTFstring(res4.nf_run_name,32,fid_res4);
res4.nf_run_title=writeCTFstring(res4.nf_run_title,-256,fid_res4);
res4.nf_instruments=writeCTFstring(res4.nf_instruments,32,fid_res4);
res4.nf_collect_descriptor=writeCTFstring(res4.nf_collect_descriptor,32,fid_res4);
res4.nf_subject_id=writeCTFstring(res4.nf_subject_id,-32,fid_res4);
res4.nf_operator=writeCTFstring(res4.nf_operator,32,fid_res4);
res4.nf_sensorFileName=writeCTFstring(res4.nf_sensorFileName,60,fid_res4);
res4.size=length(res4.run_description);      % Run_description may have been changed.
fwrite(fid_res4,res4.size,'int32');    

%  end of meg4FileSetup part of meg41GeneralResRec
fwrite(fid_res4,[0 0],'int16');                    % 4 bytes padding
res4.run_description=writeCTFstring(res4.run_description,res4.size,fid_res4);

%  filter descriptions

fwrite(fid_res4,res4.num_filters,'int16');      %2
if ~(res4.highPass == 0)
  fwrite(fid_res4,res4.highPass,'double');      %8
  fwrite(fid_res4,res4.fClass,'int32');         %4
  fType = 2; % HIGHPASS
  fwrite(fid_res4,fType,'int32');               %4
  fwrite(fid_res4,res4.fNumParams,'int16');     %2
end
fwrite(fid_res4,res4.lowPass,'double');         %8
fwrite(fid_res4,res4.fClass,'int32');           %4
fType = 1; % LOWPASS
fwrite(fid_res4,fType,'int32');                 %4
fwrite(fid_res4,res4.fNumParams,'int16');       %2


%  Write channel names.   Must have size(res4.chanNames)=[nChan 32]
no_chanNames =size(res4.chanNames,2);

for kchan=1:res4.no_channels
  s = char(res4.chanNames(kchan));
  res4.chanNamesStr(kchan,1:32)=writeCTFstring(s,32,fid_res4);
end

%  Write sensor resource table
for kchan=1:res4.no_channels
  fwrite(fid_res4,res4.senres(kchan).sensorTypeIndex,'int16');
  fwrite(fid_res4,res4.senres(kchan).originalRunNum,'int16');
  fwrite(fid_res4,res4.senres(kchan).coilShape,'int32');
  fwrite(fid_res4,res4.senres(kchan).properGain,'double');
  fwrite(fid_res4,res4.senres(kchan).qGain,'double');
  fwrite(fid_res4,res4.senres(kchan).ioGain,'double');
  fwrite(fid_res4,res4.senres(kchan).ioOffset,'double');
  fwrite(fid_res4,res4.senres(kchan).numCoils,'int16');
  numCoils=res4.senres(kchan).numCoils;
  fwrite(fid_res4,res4.senres(kchan).grad_order_no,'int16');
  fwrite(fid_res4,0,'int32');  % Padding to 8-byte boundary
  
  % coilTbl
  for qx=1:numCoils
    fwrite(fid_res4,[res4.senres(kchan).pos0(:,qx)' 0],'double');
    fwrite(fid_res4,[res4.senres(kchan).ori0(:,qx)' 0],'double');
    fwrite(fid_res4,[res4.senres(kchan).numturns(qx) 0 0 0],'int16');
    fwrite(fid_res4,res4.senres(kchan).area(qx),'double');
  end
  if numCoils<MAX_COILS
    fwrite(fid_res4,zeros(10*(MAX_COILS-numCoils),1),'double');  
  end
  
  %HdcoilTbl
  for qx=1:numCoils
    fwrite(fid_res4,[res4.senres(kchan).pos(:,qx)' 0],'double');
    fwrite(fid_res4,[res4.senres(kchan).ori(:,qx)' 0],'double');
    fwrite(fid_res4,[res4.senres(kchan).numturns(qx) 0 0 0],'int16');
    fwrite(fid_res4,res4.senres(kchan).area(qx),'double');
  end
  if numCoils<MAX_COILS
    fwrite(fid_res4,zeros(10*(MAX_COILS-numCoils),1),'double');  
  end
end
%  End writing sensor resource table

%  Write the table of balance coefficients.
if res4.numcoef<=0
  fwrite(fid_res4,res4.numcoef,'int16');  % Number of coefficient records
elseif res4.numcoef>0
  scrx_out=[];
  for kx=1:res4.numcoef
    sName=strtok(char(res4.scrr(kx).sensorName),['- ',char(0)]);
    if ~isempty(strmatch(sName,res4.chanNamesStr))
      scrx_out=[scrx_out kx];
    end
  end
  %  Remove the extra coefficient records
  res4.scrr=res4.scrr(scrx_out);
  res4.numcoef=size(res4.scrr,2);
  fwrite(fid_res4,res4.numcoef,'int16');  % Number of coefficient records
  %  Convert res4.scrr to double before writing to output file.  In MATLAB 5.3.1, 
  %  when the 'ieee-be' option is applied, fwrite cannot write anything except 
  %  doubles and character strings, even if fwrite does allow you to specify short
  %  integer formats in the output file.
  for nx=1:res4.numcoef
    fwrite(fid_res4,double(res4.scrr(nx).sensorName),'uint8');
    fwrite(fid_res4,[double(res4.scrr(nx).coefType) 0 0 0 0],'uint8');
    fwrite(fid_res4,double(res4.scrr(nx).numcoefs),'int16');
    fwrite(fid_res4,double(res4.scrr(nx).sensor),'uint8');
    fwrite(fid_res4,res4.scrr(nx).coefs,'double');
  end
end
status = fclose(fid_res4);
if status == -1
  err = status;
  return;
end

err = 0;
return


% *************************************************************************************
%*************** Function writeCTFstring ************************************************
function strng=writeCTFstring(instrng,strlength,fid)

%  Writes a character string to output unit fid.  Append nulls to get the correct length.
%  instrng : Character string.  size(instrng)=[nLine nPerLine].  strng is reformulated as a
%            long string of size [1 nChar].  Multiple lines are allowed so the user can
%            easily append text.  If necessary, characters are removed from
%            instrng(1:nLine-1,:) so all of strng(nLine,:) can be accomodated.
%    strlength: Number of characters to write.  strlength<0 means remove leading characters.
%        If abs(strlength)>length(strng) pad with nulls (char(0))
%        If 0<strlength<length(strng), truncate strng and terminate with a null.
%        If -length(string)<strlength<0, remove leading characters and terminate with a null.

%  Form a single long string
nLine=size(instrng,1);
if nLine > 0
  strng=deblank(instrng(1,:));
else
  strng = instrng;
end

if nLine>1
  %  Concatenate lines 1:nLine-1
  for k=2:nLine-1
    if length(strng)>0
      if ~strcmp(strng(length(strng)),'.') & ~strcmp(strng(length(strng)),',')
        strng=[strng '.'];   % Force a period at the end of the string.
      end
    end
    strng=[strng '  ' deblank(instrng(k,:))];
  end
  
  if length(strng)>0
    if ~strcmp(strng(length(strng)),'.')  % Force a period at the end of the string.
      strng=[strng '.'];
    end
  end
  %  Add all of the last line.
  nChar=length(strng);
  nLast=length(deblank(instrng(nLine,:)));
  strng=[strng(1:min(nChar,abs(strlength)-nLast-4)) '  ' deblank(instrng(nLine,:))];
end

if length(strng)<abs(strlength)
  strng=[strng char(zeros(1,abs(strlength)-length(strng)))];
elseif length(strng)>strlength & strlength>0
  strng=[strng(1:strlength-1) char(0)];
elseif length(strng)==strlength & strlength>0
  strng=strng;
else
   strng=[strng(nLast+[strlength+2:0]) char(0)];
end

fwrite(fid,strng,'char');
return
%  ************* End of function writeCTFstring ***************************************
% ************************************************************************************

