--kong
function onTick()
    Common_UnitConsumeActPoint(1);
    for k, v in pairs(GetDeadList()) do
        UnitRelive(v, v.hpp)
    end
end