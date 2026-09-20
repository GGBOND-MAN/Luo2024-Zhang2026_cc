function prepare_case_source(root)
% Read completed final raw; replay only the preassigned visualization seed.
arguments
    root (1,1) string
end
pkg=fullfile(root,'server_packages','round34_final_authorized_full_project_upload_20260911_115954');
addpath(fullfile(pkg,'matlab'));
dest=fullfile(root,'paper','figure_data'); if ~isfolder(dest), mkdir(dest); end
if isfile(fullfile(dest,'Fig02_replay_rejected.mat')) || isfile(fullfile(dest,'Fig02_visualization_replay.mat'))
    disp('Case visualization replay already attempted; no repeat.'); return
end
base=fullfile(pkg,'matlab','results','full_spectrum');
S=load(fullfile(base,'round34_final_test_v1','shard_02_of_02','result.mat'));
idx=find(S.design.seed==52100034); assert(isscalar(idx));
raw=S.results{idx}; row=S.design(idx,:); assert(raw.success);
front=raw.diagnostics.front; C=raw.diagnostics.C_enhanced; P=raw.diagnostics.P_A.profile;
save(fullfile(dest,'Fig02_saved_case.mat'),'raw','row','front','C','P','-v7');
writetable(table(P.grid(:),P.gridScore(:),'VariableNames',{'rangeM','rawLogScore'}),fullfile(dest,'Fig02_profile_grid.csv'));
writetable(table(P.candidates(:),P.candidateScore(:),P.candidateSource(:),'VariableNames',{'rangeM','rawLogScore','candidateSource'}),fullfile(dest,'Fig02_profile_candidates.csv'));
disp(row); disp(front.selected); disp(P.interval);
% No front-end, estimator, or optimization run. Reconstruct only missing MUSIC scores.
F=load(fullfile(base,'round34_final_test_protocol_v1','protocol.mat'));
cfg=jad.defaultConfig(); scan=fsjad.prepareScan(cfg); protocol=F.identity.protocol;
replay=fsjad.replayRound27Data(cfg,scan,row);
replayLabel="visualization replay";
hashZ=r31.arrayHash(replay.observation); hashY=r31.arrayHash(replay.snapshots);
hashMatch=(hashZ==raw.hash.observation)&&(hashY==raw.hash.snapshots);
if ~hashMatch
    save(fullfile(dest,'Fig02_replay_rejected.mat'),'cfg','protocol','row','hashZ','hashY','hashMatch','replayLabel');
    warning('paper:ReplayHashMismatch','Input hash mismatch: omit MUSIC curve.'); return
end
carriers=r30.selectLocalCarriers(cfg.numSubcarriers,protocol.r33.r32.music.carrierCount,front.peakCarrierIndex);
[state,musicCfg,cost]=r33.prepareMusicState(cfg,replay.snapshots(:,carriers+1),carriers,front.selected.thetaDeg,front.selected.rangeM,protocol.r33.r32.music.subarraySize,protocol.r33.gram,UseGram=false);
r34.assertAOnlyCost(cost,"enhanced-shared-state",protocol);
% Use original saved range nodes. Do not alter the estimator's grids or support.
rangeM=unique([C.stages.rangeGridM]).'; thetaDeg=C.thetaDeg;
rawLogScore=jad.localMusicLogScore(musicCfg,state,repmat(thetaDeg,size(rangeM)),rangeM);
atOutput=jad.localMusicLogScore(musicCfg,state,C.thetaDeg,C.rangeM);
scoreDifference=abs(atOutput-C.score);
% Use the original accepted numerical tolerance, without relaxing it.
scoreTolerance=protocol.r33.validation.candidateScoreTolerance;
scorePass=scoreDifference<=scoreTolerance;
writetable(table(hashMatch,scoreDifference,scoreTolerance,scorePass),fullfile(dest,'Fig02_replay_validation.csv'));
save(fullfile(dest,'Fig02_visualization_replay.mat'),'cfg','protocol','row','front','C','rangeM','thetaDeg','rawLogScore','replayLabel','hashZ','hashY','hashMatch','scoreDifference','scoreTolerance','scorePass','state','cost','-v7.3');
if scorePass
    writetable(table(rangeM,rawLogScore(:),'VariableNames',{'rangeM','rawLogScore'}),fullfile(dest,'Fig02_music_replay.csv'));
else
    warning('paper:ReplayScoreMismatch','Frozen tolerance failed: omit MUSIC curve.');
end
disp('CASE_SOURCE_COMPLETE');
end
