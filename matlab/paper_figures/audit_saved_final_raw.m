function audit_saved_final_raw(root)
%AUDIT_SAVED_FINAL_RAW Read saved doubles and identities; no estimator calls.
arguments
    root (1,1) string
end
pkg=fullfile(root,'server_packages','round34_final_authorized_full_project_upload_20260911_115954','matlab');
addpath(pkg); base=fullfile(pkg,'results','full_spectrum');
prot=load(fullfile(base,'round34_final_test_protocol_v1','protocol.mat'));
current=r34.manifest(pkg); sourceDigest=r32.sourceDigest(current);
assert(sourceDigest==prot.identity.sourceDigest,'Frozen source changed.');
same=0; differentSeed=[]; differentDelta=[]; count=0; failures=0;
gram=0; fallback=0; evd=0;
for shard=1:2
    s=load(fullfile(base,'round34_final_test_v1',sprintf('shard_%02d_of_02',shard),'result.mat'));
    assert(s.identity.sourceDigest==sourceDigest);
    for k=1:numel(s.results)
        q=s.results{k}; count=count+1; failures=failures+~q.success;
        ia=find(q.methodNames=="P_A"); ic=find(q.methodNames=="C_enhanced");
        delta=q.thetaDeg(ia)-q.thetaDeg(ic);
        same=same+(delta==0);
        if delta~=0
            differentSeed(end+1,1)=q.seed; %#ok<AGROW>
            differentDelta(end+1,1)=delta; %#ok<AGROW>
        end
        gram=gram+q.solverAudit.totalGramCount;
        fallback=fallback+q.solverAudit.totalFallbackCount;
        evd=evd+q.solverAudit.totalDirectCount;
    end
end
assert(count==1400 && failures==0 && same==1398);
assert(gram==0 && fallback==0 && evd==2872800);
writetable(table(count,same,failures,gram,fallback,evd,sourceDigest),fullfile(root,'paper_support','saved_raw_identity_audit.csv'));
writetable(table(differentSeed,differentDelta),fullfile(root,'paper_support','saved_mat_nonzero_angle_differences.csv'));
disp('SAVED_RAW_IDENTITY_AUDIT_PASS');
end
