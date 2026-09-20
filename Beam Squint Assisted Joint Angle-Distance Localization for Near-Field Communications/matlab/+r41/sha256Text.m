function digest = sha256Text(text)
%SHA256TEXT Hash UTF-8 text with SHA-256.

arguments
    text (1, 1) string
end

bytes = unicode2native(text, "UTF-8");
engine = javaMethod("getInstance", ...
    "java.security.MessageDigest", "SHA-256");
buffer = javaMethod("wrap", "java.nio.ByteBuffer", ...
    typecast(uint8(bytes(:)), "int8"));
engine.update(buffer);
hashBytes = typecast(engine.digest(), "uint8");
digest = lower(join(compose("%02x", hashBytes), ""));
end
