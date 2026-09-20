function digest = structHash(value)
%STRUCTHASH Hash a protocol struct with its declared field order.

arguments
    value (1, 1) struct
end

digest = r41.sha256Text(string(jsonencode(value)));
end
