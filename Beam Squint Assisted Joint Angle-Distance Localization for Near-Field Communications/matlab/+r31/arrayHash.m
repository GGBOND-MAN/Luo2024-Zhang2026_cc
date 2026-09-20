function digest = arrayHash(value)
%ARRAYHASH Compute a shape-aware SHA-256 digest of a numeric array.

arguments
    value {mustBeNumeric}
end

shape = sprintf("%dx", size(value));
header = unicode2native(class(value)+"|"+shape+"|"+string(~isreal(value)), ...
    "UTF-8");
realBytes = typecast(real(value(:)), "uint8");
imaginaryBytes = zeros(0, 1, "uint8");
if ~isreal(value)
    imaginaryBytes = typecast(imag(value(:)), "uint8");
end
engine = javaMethod("getInstance", ...
    "java.security.MessageDigest", "SHA-256");
updateBytes(engine, uint8(header(:)));
updateBytes(engine, realBytes(:));
updateBytes(engine, imaginaryBytes(:));
bytes = typecast(engine.digest(), "uint8");
digest = lower(string(reshape(dec2hex(bytes, 2).', 1, [])));
end

function updateBytes(engine, bytes)
if isempty(bytes)
    return;
end
buffer = javaMethod("wrap", "java.nio.ByteBuffer", ...
    typecast(uint8(bytes(:)), "int8"));
engine.update(buffer);
end
