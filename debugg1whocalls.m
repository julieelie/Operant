Amp_env_LowPassLogVoc{vv} = cell(length(AudioLogs),1);
        Amp_env_HighPassLogVoc{vv} = cell(length(AudioLogs),1);
        LowPassLogVoc{vv} = cell(length(AudioLogs),1);
        % bandpass filter the ambient mic recording
        Filt_RawVoc = filtfilt(sos_raw_band,1,Raw_wave{vv});
        Amp_env_Mic{vv} = running_rms(Filt_RawVoc, FS, Fhigh_power, Fs_env);
        % Low passfilter the ambient mic recording (used for cross-correlation
        % but not done anymore
        %     LowPassMicVoc{vv} = filtfilt(sos_raw_low,1,Raw_wave{vv});
        % Plot the spectrogram of the ambient microphone
        F1=figure(1);
        clf(F1)
        ColorCode = [get(groot,'DefaultAxesColorOrder');1 1 1; 0 1 1; 1 1 0];
        subplot(length(AudioLogs)+2,1,1)
        [~] = spec_only_bats(Filt_RawVoc, FS, DB_noise, FHigh_spec);
        hold on
        yyaxis right
        plot((1:length(Amp_env_Mic{vv}))/Fs_env*1000, Amp_env_Mic{vv}, 'r-', 'LineWidth',2)
        ylabel(sprintf('Amp\nMic'))
        title(sprintf('Voc %d/%d',vv,Nvoc))
        xlabel(' ')
        set(gca, 'XTick',[],'XTickLabel',{})
        
        if Manual
            pause(0.1)
            Player= audioplayer((Raw_wave{vv} - mean(Raw_wave{vv}))/std(Raw_wave{vv}), FS); %#ok<TNMLP>
            play(Player)
            pause(length(Raw_wave{vv})/FS +1)
        end
        %% Loop through the loggers and calculate envelopes
        for ll=1:length(AudioLogs)
            if isnan(Piezo_FS.(Fns_AL{ll})(vv)) || isempty(Piezo_wave.(Fns_AL{ll}){vv})
                fprintf(1, 'NO DATA for Vocalization %d from %s\n', vv, Fns_AL{ll})
            else
                % design the filters
                [z,p,k] = butter(6,BandPassFilter(1:2)/(Piezo_FS.(Fns_AL{ll})(vv)/2),'bandpass');
                sos_low = zp2sos(z,p,k);
                [z,p,k] = butter(6,BandPassFilter(2:3)/(Piezo_FS.(Fns_AL{ll})(vv)/2),'bandpass');
                sos_high = zp2sos(z,p,k);
                % filter the loggers' signals
                if sum(isnan(Piezo_wave.(Fns_AL{ll}){vv}))~=length(Piezo_wave.(Fns_AL{ll}){vv})
                    LowPassLogVoc{vv}{ll} = (filtfilt(sos_low,1,Piezo_wave.(Fns_AL{ll}){vv})); % low-pass filter the voltage trace
                    HighPassLogVoc = (filtfilt(sos_high,1,Piezo_wave.(Fns_AL{ll}){vv})); % high-pass filter the voltage trace
                    Amp_env_LowPassLogVoc{vv}{ll}=running_rms(LowPassLogVoc{vv}{ll}, Piezo_FS.(Fns_AL{ll})(vv), Fhigh_power, Fs_env);
                    Amp_env_HighPassLogVoc{vv}{ll}=running_rms(HighPassLogVoc, Piezo_FS.(Fns_AL{ll})(vv), Fhigh_power, Fs_env);
                    
                    % Plot the low pass filtered signal of each logger
                    figure(1)
                    subplot(length(AudioLogs)+2,1,ll+1)
                    [~] = spec_only_bats(LowPassLogVoc{vv}{ll}, Piezo_FS.(Fns_AL{ll})(vv), DB_noise, FHigh_spec_Logger);
                    if ll<length(AudioLogs)
                        xlabel(' '); % supress the x label output
                        set(gca,'XTick',[],'XTickLabel',{});
                    end
                    hold on
                    yyaxis right
                    plot((1:length(Amp_env_LowPassLogVoc{vv}{ll}))/Fs_env*1000, Amp_env_LowPassLogVoc{vv}{ll}, 'b-','LineWidth', 2);
                    hold on
                    plot((1:length(Amp_env_HighPassLogVoc{vv}{ll}))/Fs_env*1000, Amp_env_HighPassLogVoc{vv}{ll}, 'r-','LineWidth',2);
                    ylabel(sprintf('Amp\n%s',Fns_AL{ll}([1:3 7:end])))
                    hold off
                    if Manual
                        pause(0.1)
                        Player= audioplayer((Piezo_wave.(Fns_AL{ll}){vv}-mean(Piezo_wave.(Fns_AL{ll}){vv}))/std(Piezo_wave.(Fns_AL{ll}){vv}), Piezo_FS.(Fns_AL{ll})(vv)); %#ok<TNMLP>
                        play(Player)
                        pause(length(Raw_wave{vv})/FS +1)
                    end
                else
                    Amp_env_LowPassLogVoc{vv}{ll}=resample(nan(1,length(Piezo_wave.(Fns_AL{ll}){vv})), Fs_env, round(Piezo_FS.(Fns_AL{ll})(vv)));
                    Amp_env_HighPassLogVoc{vv}{ll}=resample(nan(1,length(Piezo_wave.(Fns_AL{ll}){vv})), Fs_env, round(Piezo_FS.(Fns_AL{ll})(vv)));
                end
            end
        end
        
        if sum(cellfun('isempty',(Amp_env_LowPassLogVoc{vv}))) == length(AudioLogs)
            fprintf(1,'CANNOT DETERMINE OWNERSHIP\n')
        else
            % Treat the case where some approximations of the calculations led to
            % slight diffreent sizes of running RMS
            Short = min(cellfun('length',Amp_env_LowPassLogVoc{vv}));
            Long = max(cellfun('length',Amp_env_LowPassLogVoc{vv}));
            if (Long-Short)>1
                error('The length of vectors of running RMS are too different than expected, please check!\n')
            elseif Long~=Short
                Amp_env_LowPassLogVoc{vv} = cellfun(@(X) X(1:Short), Amp_env_LowPassLogVoc{vv}, 'UniformOutput',false);
                Amp_env_HighPassLogVoc{vv} = cellfun(@(X) X(1:Short), Amp_env_HighPassLogVoc{vv}, 'UniformOutput',false);
            end
            Amp_env_LowPassLogVoc_MAT = cell2mat(Amp_env_LowPassLogVoc{vv});
            Amp_env_HighPassLogVoc_MAT = cell2mat(Amp_env_HighPassLogVoc{vv});
            RatioAmp = (Amp_env_LowPassLogVoc_MAT +1)./(Amp_env_HighPassLogVoc_MAT+1);
            DiffAmp = Amp_env_LowPassLogVoc_MAT-Amp_env_HighPassLogVoc_MAT;
            
            % Plot the ratio of time varying RMS, the difference in time varying
            % RMS between the high and low frequency bands and the absolute time
            % varying RMS of the low frequency band
            F2=figure(2);
            clf(F2)
            subplot(3,1,3)
            for ll=1:length(AudioLogs)
                plot(RatioAmp(ll,:), 'LineWidth',2, 'Color', ColorCode(ll,:))
                hold on
            end
            ylabel('Frequency bands Ratio')
            %         hold on
            %         for ll=1:length(AudioLogs)
            %             plot([0 size(Amp_env_LowPassLogVoc_MAT,2)], Factor_AmpRatio * RatioRMS.(Fns_AL{ll})(1)*ones(2,1), 'Color',ColorCode(ll,:),'LineStyle','--');
            %             hold on
            %         end
            %         legend({Fns_AL{:} 'calling detection threshold' 'calling detection threshold'})
            legend(Fns_AL{:})
            subplot(3,1,2)
            for ll=1:length(AudioLogs)
                plot(DiffAmp(ll,:), 'LineWidth',2, 'Color', ColorCode(ll,:))
                hold on
            end
            title('Calling vs Hearing')
            ylabel('Frequency bands Diff')
            hold on
            for ll=1:length(AudioLogs)
                plot([0 size(Amp_env_LowPassLogVoc_MAT,2)], Factor_AmpDiff * DiffRMS.(Fns_AL{ll})(1)*ones(2,1), 'Color',ColorCode(ll,:),'LineStyle','--');
                hold on
            end
            legend({Fns_AL{:} 'calling detection threshold' 'calling detection threshold'})
            subplot(3,1,1)
            for ll=1:length(AudioLogs)
                plot(Amp_env_LowPassLogVoc_MAT(ll,:), 'LineWidth',2, 'Color', ColorCode(ll,:))
                hold on
            end
            hold on
            ylabel(sprintf('Running RMS %dHz-%dHz', BandPassFilter(1:2)))
            title('Detection of vocalizations on each logger')
            for ll=1:length(AudioLogs)
                plot([0 size(Amp_env_LowPassLogVoc_MAT,2)], Factor_RMS_low(ll) * RMSLow.(Fns_AL{ll})(1)*ones(2,1), 'Color',ColorCode(ll,:),'LineStyle','--');
                hold on
            end
            
            if CheckMicChannel
                plot(Amp_env_Mic{vv}.*10^3,'LineWidth',2, 'Color', ColorCode(ll+1,:))
                hold on
                plot([0 length(Amp_env_Mic{vv})], (Factor_RMS_Mic * MeanStdAmpRawExtract(vv,1))*ones(2,1).*10^3, 'Color',ColorCode(ll+1,:),'LineStyle','--');
                hold on
            end
            legend({Fns_AL{:} 'Microphone' 'voc detection threshold' 'voc detection threshold'})
            %% Find out which calls are emitted by each individual
            Vocp = nan(size(DiffAmp) + [1 0]); % This is the output of the decision criterion to determine at each time point if a bat is vocalizing or not. each row=a logger, each column = a time point
            if CheckMicChannel
                RowSize = length(AudioLogs) +1;
            else
                RowSize = length(AudioLogs);
            end
            IndVocStartRaw{vv} = cell(RowSize,1);
            IndVocStartPiezo{vv} = cell(RowSize,1);
            IndVocStopRaw{vv} = cell(RowSize,1);
            IndVocStopPiezo{vv} = cell(RowSize,1);
            IndVocStart = cell(RowSize,1);
            IndVocStop = cell(RowSize,1);
            IndVocStartRaw_merge_local = cell(RowSize,1);
            IndVocStopRaw_merge_local = cell(RowSize,1);
            IndVocStartPiezo_merge_local = cell(RowSize,1);
            IndVocStopPiezo_merge_local = cell(RowSize,1);
            %     Xcor = cell(length(AudioLogs),1);
            RMSRatio = cell(RowSize,1);
            RMSDiff = cell(RowSize,1);
            for ll=1:RowSize
                if ll>length(AudioLogs) && CheckMicChannel % we are looking at the microphone data now
                    VocpMic = Amp_env_Mic{vv}>(Factor_RMS_Mic * MeanStdAmpRawExtract(vv,1)); % Time points above amplitude threshold on the band-pass microphone signal
                    VocpMic = reshape(VocpMic,1,length(VocpMic));
                    IndVocStart{ll} = strfind(VocpMic, ones(1,Consecutive_binsMic)); %find the first indices of every sequences of length "Consecutive_bins" higher than RMS threshold
                    if isempty(IndVocStart{ll})
                        fprintf(1,'No vocalization detected on microphone\n');
                    else% Some vocalizations were detected
                        IndVocStart_diffind = find(diff(IndVocStart{ll})>1);
                        IndVocStart{ll} = [IndVocStart{ll}(1) IndVocStart{ll}(IndVocStart_diffind +1)]; % these two lines get rid of overlapping sequences that werer detected several times
                        NV = length(IndVocStart{ll}); % This is the number of detected potential vocalization
                        IndVocStop{ll} = nan(1,NV);
                        NewCall1OldCall0_temp = nan(NV,1);
                        for ii=1:NV
                            IVStop = find(VocpMic(IndVocStart{ll}(ii):end)==0, 1, 'first');
                            if ~isempty(IVStop)
                                IndVocStop{ll}(ii) = IndVocStart{ll}(ii) + IVStop -1;
                            else
                                IndVocStop{ll}(ii) = length(VocpMic);
                            end
                            % Plot the localization of that sound extract on figure 3
                            % Duplicate the figure of the spectrogram for manual input purposes
                            F3 = figure(3);
                            clf(F3)
                            %                   cla
                            [~] = spec_only_bats(Filt_RawVoc, FS, DB_noise, FHigh_spec);
                            title(sprintf('Ambient Microphone Voc %d/%d',vv,Nvoc))
                            hold on
                            yyaxis right
                            plot([IndVocStart{ll}(ii)/Fs_env IndVocStop{ll}(ii)/Fs_env]*1000, [ll ll], 'k:', 'LineWidth',2)
                            ylabel('Logger ID')
                            set(gca, 'YTick', 1:ll, 'YTickLabel', [Fns_AL; 'Mic'], 'YLim', [0 (length(AudioLogs)+2)],'YDir', 'reverse')
                            hold off
                            
                            % Decide if that call was already detected and ID
                            % attributed or not by looking if there is any
                            % overlap
                            OverlapOnset = nan(ll-1,1);
                            OverlapOffset = nan(ll-1,1);
                            for ll2=1:(ll-1)
                                OverlapOnset(ll2) = any((IndVocStart{ll2}<=IndVocStart{ll}(ii)) .* (IndVocStop{ll2}>=IndVocStart{ll}(ii)));
                                OverlapOffset(ll2) = any((IndVocStop{ll2}<=IndVocStart{ll}(ii)) .* (IndVocStop{ll2}>=IndVocStop{ll}(ii)));
                            end
                            
                            NewCall1OldCall0_temp(ii) = ~any([OverlapOnset; OverlapOffset]);
                            
                            % update figure(3) with the decision
                            figure(3)
                            yyaxis right
                            hold on
                            if NewCall1OldCall0_temp(ii)
                                text(IndVocStop{ll}(ii)/Fs_env*1000, ll, 'New call')
                            else
                                text(IndVocStop{ll}(ii)/Fs_env*1000, ll, 'Call already attributed')
                            end
                            hold off
                            
                            if NewCall1OldCall0_temp(ii)
                                fprintf(1,'New call\n');
                            else
                                fprintf(1,'Call already attributed\n');
                            end
                            Agree = input('Do you agree? yes [], No (type anything)\n','s');
                            if ~isempty(Agree)
                                NewCall1OldCall0_temp(ii) = input('Indicate your choice: new call (1) already known/noise (0)\n');
                            end
                            
                            % update figure(3) with the decision
                            figure(3)
                            yyaxis right
                            hold on
                            if NewCall1OldCall0_temp(ii)
                                plot([IndVocStart{ll}(ii)/Fs_env IndVocStop{ll}(ii)/Fs_env]*1000, [ll ll], 'Color',ColorCode(ll,:), 'LineWidth',2, 'LineStyle','-')
                                text(IndVocStop{ll}(ii)/Fs_env*1000, ll+0.2, 'New call','Color','r','FontWeight','bold')
                            else
                                plot([IndVocStart{ll}(ii)/Fs_env IndVocStop{ll}(ii)/Fs_env]*1000, [ll ll], 'k-', 'LineWidth',2)
                                text(IndVocStop{ll}(ii)/Fs_env*1000, ll+0.2, 'Call already attributed/noise','Color','r','FontWeight','bold')
                            end
                            hold off
                            
                        end
                        
                        % Only keep vocalizations that were produced by the bat
                        % according to the high RMSRatio value
                        IndVocStart{ll} = IndVocStart{ll}(logical(NewCall1OldCall0_temp));
                        IndVocStop{ll} = IndVocStop{ll}(logical(NewCall1OldCall0_temp));
                        IndVocStartRaw{vv}{ll} = round(IndVocStart{ll}/Fs_env*FS);
                        IndVocStopRaw{vv}{ll} = round(IndVocStop{ll}/Fs_env*FS);
                        NV = sum(NewCall1OldCall0_temp);
                        
                        if NV
                            % Now merge detected vocalizations that are within MergeThresh
                            Merge01 = (IndVocStart{ll}(2:end)-IndVocStop{ll}(1:(end-1)) < (MergeThresh/1000*Fs_env));
                            NV = NV-sum(Merge01);
                            IndVocStartRaw_merge_local{ll} = nan(1,NV);
                            IndVocStopRaw_merge_local{ll} = nan(1,NV);
                            IndVocStartPiezo_merge_local{ll} = nan(1,NV); % There is no useful piezo data for a call detected only on Microphone, it will stay Nan
                            IndVocStopPiezo_merge_local{ll} = nan(1,NV);% There is no useful piezo data for a call detected only on Microphone, it will stay Nan
                            CutInd = find(~Merge01);
                            IndVocStartRaw_merge_local{ll}(1) = round(IndVocStart{ll}(1)/Fs_env*FS);
                            IndVocStopRaw_merge_local{ll}(end) = round(IndVocStop{ll}(end)/Fs_env*FS);
                            for cc=1:length(CutInd)
                                IndVocStopRaw_merge_local{ll}(cc) = round(IndVocStop{ll}( CutInd(cc))/Fs_env*FS);
                                IndVocStartRaw_merge_local{ll}(cc+1) = round(IndVocStart{ll}(CutInd(cc)+1)/Fs_env*FS);
                            end
                            
                            % Now plot the onset/offset of each extract on the
                            % spectrograms of the microphone
                            figure(1)
                            for ii=1:NV
                                subplot(length(AudioLogs)+2,1,1)
                                hold on
                                yyaxis right
                                YLim = get(gca, 'YLim');
                                plot([IndVocStartRaw_merge_local{ll}(ii) IndVocStopRaw_merge_local{ll}(ii)]/FS*1000, [YLim(2)*4/5 YLim(2)*4/5], 'k-', 'LineWidth',2)
                                subplot(length(AudioLogs)+2,1,length(AudioLogs)+2)
                                hold on
                                plot([IndVocStartRaw_merge_local{ll}(ii) IndVocStopRaw_merge_local{ll}(ii)]/FS*1000, [ll ll], 'Color',ColorCode(ll,:), 'LineWidth',2, 'LineStyle','-')
                                hold off
                            end
                            
                        end
                    end
                elseif ll<=length(AudioLogs)
                    Vocp(ll,:) = Amp_env_LowPassLogVoc_MAT(ll,:)>(Factor_RMS_low(ll) * RMSLow.(Fns_AL{ll})(1)); % Time points above amplitude threshold on the low-passed logger signal
                    IndVocStart{ll} = strfind(Vocp(ll,:), ones(1,Consecutive_binsPiezo)); %find the first indices of every sequences of length "Consecutive_bins" higher than RMS threshold
                    if isempty(IndVocStart{ll})
                        fprintf('No vocalization detected on %s\n',Fns_AL{ll});
                    else% Some vocalizations were detected
                        IndVocStart_diffind = find(diff(IndVocStart{ll})>1);
                        IndVocStart{ll} = [IndVocStart{ll}(1) IndVocStart{ll}(IndVocStart_diffind +1)]; % these two lines get rid of overlapping sequences that werer detected several times
                        NV = length(IndVocStart{ll}); % This is the number of detected potential vocalization
                        IndVocStop{ll} = nan(1,NV);
                        %             Xcor{ll} = nan(NV,1);
                        RMSRatio{ll} = nan(NV,1);
                        RMSDiff{ll} = nan(NV,1);
                        Call1Hear0_temp = nan(NV,1);
                        for ii=1:NV
                            IVStop = find(Vocp(ll,IndVocStart{ll}(ii):end)==0, 1, 'first');
                            if ~isempty(IVStop)
                                IndVocStop{ll}(ii) = IndVocStart{ll}(ii) + IVStop -1;
                            else
                                IndVocStop{ll}(ii) = length(Vocp(ll,:));
                            end
                            % Plot the localization of that sound extract on figure 3
                            % Duplicate the figure of the spectrogram for manual input purposes
                            F3 = figure(3);
                            clf(F3)
                            %                   cla
                            [~] = spec_only_bats(Filt_RawVoc, FS, DB_noise, FHigh_spec);
                            title(sprintf('Ambient Microphone Voc %d/%d',vv,Nvoc))
                            hold on
                            yyaxis right
                            plot([IndVocStart{ll}(ii)/Fs_env IndVocStop{ll}(ii)/Fs_env]*1000, [ll ll], 'k:', 'LineWidth',2)
                            ylabel('Logger ID')
                            set(gca, 'YTick', 1:ll, 'YTickLabel', Fns_AL, 'YLim', [0 (length(AudioLogs)+1)],'YDir', 'reverse')
                            hold off
                            
                            %                 IndVocStartRaw{ll}(ii) = round(IndVocStart{ll}(ii)/Fs_env*FS);
                            %                 IndVocStopRaw{ll}(ii) = round(IndVocStop{ll}(ii)/Fs_env*FS);
                            %                 IndVocStartPiezo{ll}(ii) = round(IndVocStart{ll}(ii)/Fs_env*Piezo_FS.(Fns_AL{ll})(vv));
                            %                 IndVocStopPiezo{ll}(ii) = round(IndVocStop{ll}(ii)/Fs_env*Piezo_FS.(Fns_AL{ll})(vv));
                            
                            % Cross-correlate each sound extract with the raw trace and
                            % check if it has a value of cross correlation high enough
                            % to be kept as a vocalization  %% NOT Working :-(
                            %                 Resamp_Filt_Logger_wav = resample(LowPassLogVoc{vv}{ll}(IndVocStartPiezo{ll}(ii):IndVocStopPiezo{ll}(ii)), 4*BandPassFilter(2),round(Piezo_FS.(Fns_AL{ll})(vv)));
                            %                 Resamp_Filt_Raw_wav = resample(LowPassMicVoc{vv}(IndVocStartRaw{ll}(ii):IndVocStopRaw{ll}(ii)), 4*BandPassFilter(2),FS);
                            %                 [Xcor_local,~] = xcorr(Resamp_Filt_Raw_wav,Resamp_Filt_Logger_wav, (Buffer*2)*4*BandPassFilter(2), 'unbiased');
                            %                 Xcor{ll}(ii) = max(Xcor_local)/(var(Resamp_Filt_Raw_wav)*var(Resamp_Filt_Logger_wav))^0.5;
                            
                            % Calculate the Average RMS Ratio for each sound extract
                            % and decide about the vocalization ownership
                            RMSRatio{ll}(ii) = mean(RatioAmp(ll,IndVocStart{ll}(ii):IndVocStop{ll}(ii)));
                            RMSDiff{ll}(ii) = mean(DiffAmp(ll,IndVocStart{ll}(ii):IndVocStop{ll}(ii)));
                            %                     Call1Hear0_temp(ii) = RMSRatio{ll}(ii) > Factor_AmpRatio * RatioRMS.(Fns_AL{ll})(1);
                            Call1Hear0_temp(ii) = RMSDiff{ll}(ii) > Factor_AmpDiff * DiffRMS.(Fns_AL{ll})(1);
                            
                            % update figure(3) with the decision
                            figure(3)
                            yyaxis right
                            hold on
                            if Call1Hear0_temp(ii)
                                text(IndVocStop{ll}(ii)/Fs_env*1000, ll, sprintf('%s calling',Fns_AL{ll}))
                            else
                                text(IndVocStop{ll}(ii)/Fs_env*1000, ll, sprintf('%s hearing/noise',Fns_AL{ll}))
                            end
                            hold off
                            
                            if Call1Hear0_temp(ii)
                                fprintf('%s calling\n',Fns_AL{ll});
                            else
                                fprintf('%s hearing/noise\n',Fns_AL{ll});
                            end
                            Agree = input('Do you agree? yes [], No (type anything)\n','s');
                            if ~isempty(Agree)
                                Call1Hear0_temp(ii) = input('Indicate your choice: calling (1) hearing/noise (0)\n');
                            end
                            
                            % update figure(3) with the decision
                            figure(3)
                            yyaxis right
                            hold on
                            if Call1Hear0_temp(ii)
                                plot([IndVocStart{ll}(ii)/Fs_env IndVocStop{ll}(ii)/Fs_env]*1000, [ll ll], 'Color',ColorCode(ll,:), 'LineWidth',2, 'LineStyle','-')
                                text(IndVocStop{ll}(ii)/Fs_env*1000, ll+0.2, sprintf('%s calling',Fns_AL{ll}),'Color','r','FontWeight','bold')
                            else
                                plot([IndVocStart{ll}(ii)/Fs_env IndVocStop{ll}(ii)/Fs_env]*1000, [ll ll], 'k-', 'LineWidth',2)
                                text(IndVocStop{ll}(ii)/Fs_env*1000, ll+0.2, sprintf('%s hearing',Fns_AL{ll}),'Color','r','FontWeight','bold')
                            end
                            hold off
                            
                            
                            %                 figure(1)
                            %                 subplot(length(AudioLogs)+2,1,ll+1)
                            %                 hold on
                            %                 yyaxis right
                            %                 YLim = get(gca, 'YLim');
                            %                 if Call1Hear0_temp{ll}(ii)
                            %                     plot([IndVocStart{ll}(ii) IndVocStop{ll}(ii)]/Fs_env*1000, [YLim(2)*4/5 YLim(2)*4/5], 'k-', 'LineWidth',2)
                            %                     subplot(length(AudioLogs)+2,1,length(AudioLogs)+2)
                            %                     hold on
                            %                     plot([IndVocStart{ll}(ii) IndVocStop{ll}(ii)]/Fs_env*1000, [ll ll], 'Color',ColorCode(ll,:), 'LineWidth',2, 'LineStyle','-')
                            %                     hold off
                            %                 else
                            %                     plot([IndVocStart{ll}(ii) IndVocStop{ll}(ii)]/Fs_env*1000, [YLim(2)*4/5 YLim(2)*4/5], 'LineStyle','-','Color',[0.8 0.8 0.8], 'LineWidth',2)
                            %                 end
                            %                 hold off
                            
                        end
                        
                        % Only keep vocalizations that were produced by the bat
                        % according to the high RMSRatio value
                        IndVocStart{ll} = IndVocStart{ll}(logical(Call1Hear0_temp));
                        IndVocStop{ll} = IndVocStop{ll}(logical(Call1Hear0_temp));
                        IndVocStartRaw{vv}{ll} = round(IndVocStart{ll}/Fs_env*FS);
                        IndVocStartPiezo{vv}{ll} = round(IndVocStart{ll}/Fs_env*Piezo_FS.(Fns_AL{ll})(vv));
                        IndVocStopRaw{vv}{ll} = round(IndVocStop{ll}/Fs_env*FS);
                        IndVocStopPiezo{vv}{ll} = round(IndVocStop{ll}/Fs_env*Piezo_FS.(Fns_AL{ll})(vv));
                        NV = sum(Call1Hear0_temp);
                        
                        if NV
                            % Now merge detected vocalizations that are within MergeThresh
                            Merge01 = (IndVocStart{ll}(2:end)-IndVocStop{ll}(1:(end-1)) < (MergeThresh/1000*Fs_env));
                            NV = NV-sum(Merge01);
                            IndVocStartRaw_merge_local{ll} = nan(1,NV);
                            IndVocStopRaw_merge_local{ll} = nan(1,NV);
                            IndVocStartPiezo_merge_local{ll} = nan(1,NV);
                            IndVocStopPiezo_merge_local{ll} = nan(1,NV);
                            CutInd = find(~Merge01);
                            IndVocStartRaw_merge_local{ll}(1) = round(IndVocStart{ll}(1)/Fs_env*FS);
                            IndVocStartPiezo_merge_local{ll}(1) = round(IndVocStart{ll}(1)/Fs_env*Piezo_FS.(Fns_AL{ll})(vv));
                            IndVocStopRaw_merge_local{ll}(end) = round(IndVocStop{ll}(end)/Fs_env*FS);
                            IndVocStopPiezo_merge_local{ll}(end) = round(IndVocStop{ll}(end)/Fs_env*Piezo_FS.(Fns_AL{ll})(vv));
                            for cc=1:length(CutInd)
                                IndVocStopRaw_merge_local{ll}(cc) = round(IndVocStop{ll}( CutInd(cc))/Fs_env*FS);
                                IndVocStopPiezo_merge_local{ll}(cc) = round(IndVocStop{ll}(CutInd(cc))/Fs_env*Piezo_FS.(Fns_AL{ll})(vv));
                                IndVocStartRaw_merge_local{ll}(cc+1) = round(IndVocStart{ll}(CutInd(cc)+1)/Fs_env*FS);
                                IndVocStartPiezo_merge_local{ll}(cc+1) = round(IndVocStart{ll}(CutInd(cc)+1)/Fs_env*Piezo_FS.(Fns_AL{ll})(vv));
                            end
                            
                            % Now plot the onset/offset of each extract on the
                            % spectrograms of the loggers
                            figure(1)
                            for ii=1:NV
                                subplot(length(AudioLogs)+2,1,ll+1)
                                hold on
                                yyaxis right
                                YLim = get(gca, 'YLim');
                                plot([IndVocStartRaw_merge_local{ll}(ii) IndVocStopRaw_merge_local{ll}(ii)]/FS*1000, [YLim(2)*4/5 YLim(2)*4/5], 'k-', 'LineWidth',2)
                                subplot(length(AudioLogs)+2,1,length(AudioLogs)+2)
                                hold on
                                plot([IndVocStartRaw_merge_local{ll}(ii) IndVocStopRaw_merge_local{ll}(ii)]/FS*1000, [ll ll], 'Color',ColorCode(ll,:), 'LineWidth',2, 'LineStyle','-')
                                hold off
                            end
                            
                            %             subplot(length(AudioLogs)+2,1,ll+1)
                            %             hold on
                            %             yyaxis right
                            %             YLim = get(gca, 'YLim');
                            %             for ii=1:NV
                            %                 if Call1Hear0{ll}(ii)
                            %                     plot(round([IndVocStartRaw{ll}(ii) IndVocStopRaw{ll}(ii)]/FS*1000), [YLim(2)*4.5/5 YLim(2)*4.5/5], 'r-', 'LineWidth',2)
                            %                 else
                            %                     plot(round([IndVocStartRaw{ll}(ii) IndVocStopRaw{ll}(ii)]/FS*1000), [YLim(2)*4.5/5 YLim(2)*4.5/5], '-', 'LineWidth',2, 'Color',[1 0.5 0.5])
                            %                 end
                            %             end
                            %             hold off
                        end
                    end
                end
            end
            figure(1)
            subplot(length(AudioLogs)+2,1,1)
            XLIM = get(gca, 'XLim');
            subplot(length(AudioLogs)+2,1,length(AudioLogs)+2)
            set(gca, 'YTick', 1:length(AudioLogs))
            set(gca, 'YTickLabel', [Fns_AL; 'Mic'])
            set(gca, 'YLim', [0 length(AudioLogs)+1])
            set(gca, 'XLim', XLIM);
            ylabel('AL ID')
            xlabel('Time (ms)')
            [~,FileVoc]=fileparts(VocFilename{vv}); %#ok<IDISVAR,USENS>
            print(F1,fullfile(Loggers_dir,sprintf('%s_whocalls_spec_%d.pdf', FileVoc, MergeThresh)),'-dpdf','-fillpage')
            saveas(F2,fullfile(Loggers_dir,sprintf('%s_whocalls_RMS_%d.pdf', FileVoc, MergeThresh)),'pdf')
            
            pause(1)
            clf(F1)
            clf(F2)
            
            % Gather Vocalization production data:
            IndVocStart_all{vv} = IndVocStart;
            IndVocStop_all{vv} = IndVocStop;
            IndVocStartRaw_merged{vv} = IndVocStartRaw_merge_local;
            IndVocStopRaw_merged{vv} = IndVocStopRaw_merge_local;
            IndVocStartPiezo_merged{vv} = IndVocStartPiezo_merge_local;
            IndVocStopPiezo_merged{vv} = IndVocStopPiezo_merge_local;
            RMSRatio_all{vv} = RMSRatio;
            RMSDiff_all{vv} = RMSDiff;
        end
        save(fullfile(Loggers_dir, sprintf('%s_%s_VocExtractData_%d.mat', Date, ExpStartTime, MergeThresh)), 'IndVocStartRaw_merged', 'IndVocStopRaw_merged', 'IndVocStartPiezo_merged', 'IndVocStopPiezo_merged', 'IndVocStart_all', 'IndVocStop_all','RMSRatio_all','RMSDiff_all','vv');