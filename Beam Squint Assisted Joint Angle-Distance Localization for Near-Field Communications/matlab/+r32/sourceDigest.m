function digest = sourceDigest(source)
%SOURCEDIGEST Collapse a source manifest into one deterministic digest.

arguments
    source table
end

ordered = sortrows(source, "path");
text = join(ordered.path+"|"+ordered.sha256+"|"+string(ordered.bytes), newline);
bytes = unicode2native(text, "UTF-8");
engine = javaMethod("getInstance", ...
    "java.security.MessageDigest", "SHA-256");
buffer = javaMethod("wrap", "java.nio.ByteBuffer", ...
    typecast(uint8(bytes(:)), "int8"));
engine.update(buffer);
hashBytes = typecast(engine.digest(), "uint8");
digest = lower(join(compose("%02x", hashBytes), ""));
end
