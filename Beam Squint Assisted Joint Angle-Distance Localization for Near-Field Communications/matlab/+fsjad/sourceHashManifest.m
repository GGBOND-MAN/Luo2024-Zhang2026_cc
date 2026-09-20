function manifest = sourceHashManifest(project, relativePaths)
%SOURCEHASHMANIFEST Record SHA-256 hashes for reproducible experiment code.

arguments
    project (1, 1) string
    relativePaths (:, 1) string
end

relativePaths = unique(relativePaths, "stable");
sha256 = strings(size(relativePaths));
bytes = zeros(size(relativePaths));
for index = 1:numel(relativePaths)
    file = fullfile(project, relativePaths(index));
    if ~isfile(file)
        error("fsjad:MissingSourceFile", "Missing source file: %s", file);
    end
    handle = fopen(file, "rb");
    if handle < 0
        error("fsjad:SourceReadFailed", "Cannot read source file: %s", file);
    end
    cleanup = onCleanup(@() fclose(handle));
    content = fread(handle, Inf, "*uint8");
    clear cleanup
    digest = java.security.MessageDigest.getInstance("SHA-256");
    digest.update(content);
    hashBytes = typecast(digest.digest(), "uint8");
    sha256(index) = lower(join(compose("%02x", hashBytes), ""));
    bytes(index) = numel(content);
end
manifest = table(relativePaths, bytes, sha256, ...
    'VariableNames', {'path', 'bytes', 'sha256'});
end
