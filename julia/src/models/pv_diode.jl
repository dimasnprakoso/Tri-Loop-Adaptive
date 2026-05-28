"""
Single-diode PV model with irradiance G [W/m²] and cell temperature Tc [°C].
Returns I-V relation as a residual; use `pv_current` and `pv_power`.

Iph(G,T) = (Iph_stc + Ki*(T-T_stc)) * G/G_stc
Vt(T)    = a*Ns*k*T/q
I        = Iph - I0*(exp((V+I*Rs)/Vt) - 1) - (V+I*Rs)/Rsh
"""
function pv_iv_residual(I, V, G, Tc, p::SystemParams)
    Tk = Tc + 273.15
    Vt = p.a * p.Ns * 1.380649e-23 * Tk / 1.602176634e-19
    Iph = (p.Iph_stc + p.Ki*(Tc - p.T_stc)) * G/p.G_stc
    return Iph - p.I0*(exp((V + I*p.Rs)/(p.Ns*Vt)) - 1) - (V + I*p.Rs)/(p.Ns*p.Rsh) - I
end

"""Solve for PV current given terminal voltage, irradiance, and temperature.
Returns array-level current [A]."""
function pv_current(V::Real, G::Real, Tc::Real, p::SystemParams)
    # Below ~10 W/m² PV output is < 1% rated and find_zero may fail to
    # bracket; treat as effectively zero.
    G <= 10.0 && return 0.0
    Iph_max = (p.Iph_stc + p.Ki*max(Tc - p.T_stc, 0.0)) * G/p.G_stc
    try
        Iarr = Roots.find_zero(I -> pv_iv_residual(I, V, G, Tc, p),
                                (0.0, max(Iph_max*1.5, 0.5)); atol=1e-6)
        return Iarr * p.Np_strings
    catch
        return 0.0
    end
end

"""PV array power [W] at terminal voltage V [V] under (G, Tc)."""
function pv_power(V::Real, G::Real, Tc::Real, p::SystemParams)
    return V * pv_current(V, G, Tc, p)
end

"""
Approximate MPP voltage by 1-D bracketing search.
Returns (V_mpp, P_mpp). Uses derivative-zero crossing of P(V).
"""
function pv_mpp(G::Real, Tc::Real, p::SystemParams;
                Vmin::Real=0.6*p.Ns_modules*30.0, Vmax::Real=1.0*p.Ns_modules*40.0)
    G <= 10.0 && return (V=0.0, P=0.0)
    Vs = range(Vmin, Vmax; length=80)
    Ps = [pv_power(v, G, Tc, p) for v in Vs]
    k = argmax(Ps)
    return (V=Vs[k], P=Ps[k])
end
