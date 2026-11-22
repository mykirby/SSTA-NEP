### A Pluto.jl notebook ###
# v0.19.40

using Markdown
using InteractiveUtils

# This Jupyter-style cell generates bound slider variables.
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(iv, el) ? iv(el) : missing
        el
    end
end

# ╔═╡ 53b0d087-954b-408e-8b3f-86fc9ff1742e
md"""
# Designing Hall Thruster Geometry with HallThruster.jl

This is a **Pluto.jl notebook** — reactive, so changing a slider or variable in one cell automatically re-runs every cell that depends on it. That makes it well suited to geometry trade studies: drag a slider for channel length or width and watch thrust, efficiency, and field profiles update live.

This notebook builds on the standard [HallThruster.jl](https://github.com/UM-PEPL/HallThruster.jl) workflow [doc1][doc2] but focuses specifically on **geometry design**: channel length, inner/outer radius, channel width, and the magnetic field topology that must scale with them.

**How to use this notebook:**
1. Install [Pluto.jl](https://plutojl.org/) (`] add Pluto`), then run `using Pluto; Pluto.run()` and open this file.
2. Run cells top to bottom once to get your bearings — after that, use the sliders in §4 and §6 interactively.

"""

# ╔═╡ a8da3bc7-fd7d-4a51-af24-efe372a6e93d
begin
	using Pkg
	Pkg.activate(mktempdir())
	Pkg.add(["HallThruster", "Unitful", "CairoMakie", "PlutoUI"])
	using HallThruster: HallThruster as het
	using Unitful
	using CairoMakie
	using PlutoUI
end

# ╔═╡ 253088a2-1fb9-48f3-9e44-7ddd2de9ef4d
md"""
## 1. Background: what "geometry" means in HallThruster.jl

The discharge channel is a `Geometry1D` struct with three core parameters [doc1][doc2]:

- `channel_length` — axial length of the discharge channel (m)
- `inner_radius` — inner channel wall radius (m)
- `outer_radius` — outer channel wall radius (m)

From these the code derives channel cross-sectional area, which sets current density for a given mass flow rate. Dimensions are meters by default, or you can use `Unitful`/`DynamicQuantities` units (e.g. `5.0u"cm"`) and HallThruster.jl converts automatically [doc1][doc2].

A `Thruster` bundles geometry with a magnetic field profile and a shielding flag [doc1][doc2]:

```julia
thruster = het.Thruster(
    name = "My Design",
    geometry = geom,
    magnetic_field = bfield,
    shielded = false,
)
```

**Key coupling for geometry design:** the magnetic field's peak (normally placed at/near the channel exit) must be re-scaled whenever `channel_length` changes, since the field is a function or lookup table of axial position `z` [doc2]. The parametric builder in §2 handles this automatically.

"""

# ╔═╡ 4cbbd0a8-897c-4525-80f6-f862cd8ea295
md"""
## 2. A parametric thruster builder

Rather than hand-editing one fixed case, we write a function that builds `Geometry1D`, a magnetic field scaled to the new channel exit, a `Thruster`, and a `Config` from a handful of design variables. This is the core reusable piece of the whole notebook.

"""

# ╔═╡ 81434d76-d0be-4769-92d2-06051ac80c49
"""
	bfield_profile(L; B_max=0.02)

Return a callable Gaussian magnetic-field profile (in Tesla) scaled to peak
at the channel exit `z = L` (meters). Upstream/downstream widths scale
with channel length.
"""
function bfield_profile(L; B_max = 0.02)
	Lval = ustrip(u"m", L)
	function bfield_fn(z)
		z_exit = Lval
		zm = ustrip(u"m", z)
		if zm < z_exit
			return B_max * exp(-((zm - z_exit) / (0.67 * Lval))^2)
		else
			return B_max * exp(-((zm - z_exit) / (1.33 * Lval))^2)
		end
	end
	return bfield_fn
end

"""
	build_thruster(L, r_in, r_out; B_max=0.02, name="design")

Build a `Thruster` given three geometric design variables:
- `L`     : channel length
- `r_in`  : inner channel radius
- `r_out` : outer channel radius

A Gaussian magnetic field profile is scaled to peak at the channel exit
(z = L), with upstream/downstream widths proportional to channel length
(a common scaling heuristic for a first-pass design study).
"""
function build_thruster(L, r_in, r_out; B_max = 0.02, name = "design")
	geom = het.Geometry1D(
		channel_length = L,
		inner_radius   = r_in,
		outer_radius   = r_out,
	)

	bfn = bfield_profile(L; B_max = B_max)
	# Sample the profile over a range covering the simulation domain so the
	# MagneticField lookup table can be interpolated (and mildly extrapolated)
	# at any grid point.
	zs = collect(range(0.0, 0.5, length = 501))
	Bs = [bfn(z * u"m") for z in zs]
	mf = het.MagneticField(; z = zs, B = Bs)

	het.Thruster(
		name = name,
		geometry = geom,
		magnetic_field = mf,
		shielded = false,
	)
end

# ╔═╡ 66186ef2-ced0-46a9-9981-cacf5b494688
"""
	make_config(thruster; V=300.0u"V", mdot=5u"mg/s", domain_end=0.08u"m")

Wrap a `Thruster` in a `Config`, following the standard workflow [doc1][doc2].
`domain_end` should extend past the channel exit into the plume regardless
of channel length.
"""
function make_config(thruster; V = 300.0u"V", mdot = 5u"mg/s", domain_end = 0.08u"m")
	het.Config(
		thruster = thruster,
		domain = (0.0u"m", domain_end),
		discharge_voltage = V,
		propellants = [het.Propellant("Xe", flow_rate_kg_s = mdot, allowed_charges = [1])],
	)
end

# ╔═╡ b4bcf506-d8e7-43da-919c-8b33ccdd08a6
md"""
## 3. A quick look at the magnetic field profile

Before running any plasma physics, sanity-check the B-field scaling against the geometry — this is the step most likely to silently wreck a geometry sweep if skipped [doc1][doc2].

"""

# ╔═╡ 9ac340d5-8b60-403e-8b68-3df8f3c47cd4
let
	L_check = 0.025u"m"
	bfn = bfield_profile(L_check)
	zs = range(0, 0.08, length = 300)
	Bs = bfn.(zs .* u"m")

	fig = Figure(size = (500, 300))
	ax = Axis(fig[1, 1], xlabel = "z (m)", ylabel = "B (T)", title = "B-field for L = $(L_check)")
	vlines!(ax, [ustrip(u"m", L_check)], color = :gray, linestyle = :dash, label = "channel exit")
	lines!(ax, collect(zs), Bs)
	axislegend(ax)
	fig
end

# ╔═╡ d4f67adc-2c38-4e00-bc90-c5bfe8f365e1
md"""
## 4. Interactive single-case run

Drag the sliders below to pick a geometry, then run the simulation cell. Because Pluto is reactive, changing a slider will automatically mark the simulation cell as stale — click the ▶ button (or it auto-reruns, depending on your settings) to resolve it.

> **Note:** each run takes on the order of tens of seconds on a modest grid [doc2]. For quick interactive exploration, keep `duration` short (a few hundred µs) and increase it later for a final, trusted result.

"""

# ╔═╡ 530bec76-36ef-486f-a664-9d546fa31698
@bind L_slider PlutoUI.Slider(0.01:0.0025:0.04, default = 0.025, show_value = true)

# ╔═╡ f59d8c15-3b52-4a40-b01e-1fc90f5bea1f
@bind rin_slider PlutoUI.Slider(0.02:0.0025:0.045, default = 0.0345, show_value = true)

# ╔═╡ db45a324-b8d8-4ee1-94a2-89fe76fe7f65
@bind rout_slider PlutoUI.Slider(0.045:0.0025:0.07, default = 0.05, show_value = true)

# ╔═╡ b9a1795b-7265-4851-aa5e-725d3e9506e9
md"""
**Current geometry:** L = $(L_slider) m, r\_in = $(rin_slider) m, r\_out = $(rout_slider) m
(channel width = $(round(rout_slider - rin_slider, digits=4)) m)
"""

# ╔═╡ 11f3ca8c-bc1d-4340-87cb-dd5cf780fca5
begin
	thruster_interactive = build_thruster(L_slider * u"m", rin_slider * u"m", rout_slider * u"m"; name = "interactive")
	config_interactive = make_config(thruster_interactive)

	simparams_interactive = het.SimParams(
		grid = het.EvenGrid(100),
		dt = 5u"ns",
		duration = 500u"μs",   # short duration for interactive speed; lengthen for final results
		num_save = 200,
	)

	solution_interactive = het.run_simulation(config_interactive, simparams_interactive)
end

# ╔═╡ ed0f779a-777d-4d6d-94ef-0413239c1fa1
begin
	avg_interactive = het.time_average(solution_interactive, 250u"μs")

	T_i     = het.thrust(avg_interactive)[]
	Id_i    = het.discharge_current(avg_interactive)[]
	eta_a_i = het.anode_eff(avg_interactive)[]
	eta_m_i = het.mass_eff(avg_interactive)[]
	eta_I_i = het.current_eff(avg_interactive)[]
	eta_V_i = het.voltage_eff(avg_interactive)[]

	md"""
	**Performance for this geometry:**

	| Metric | Value |
	|---|---|
	| Thrust | $(round(T_i, digits=5)) N |
	| Discharge current | $(round(Id_i, digits=3)) A |
	| Anode efficiency | $(round(eta_a_i, digits=3)) |
	| Mass utilization efficiency | $(round(eta_m_i, digits=3)) |
	| Current utilization efficiency | $(round(eta_I_i, digits=3)) |
	| Voltage utilization efficiency | $(round(eta_V_i, digits=3)) |
	"""
end

# ╔═╡ fc8477c1-dbfc-44f8-a101-4ff5c98c17e2
md"""
These efficiency terms tell you *why* a geometry change helped or hurt [doc2]:

- **Mass utilization efficiency** — ion beam mass flow / total anode flow. Short channels tend to leak more un-ionized neutrals.
- **Current utilization efficiency** — ion current / discharge current. Sensitive to channel width and wall material (`wall_loss_model`) [doc3].
- **Voltage utilization efficiency** — how much of the discharge voltage actually accelerates ions axially. Sensitive to B-field placement relative to geometry.

"""

# ╔═╡ abf1ad3b-54c2-49e0-a8d4-33d2cde840e9
let
	z_cm = avg_interactive.grid .* 100
	fig = Figure(size = (600, 350))

	ax1 = Axis(fig[1, 1], xlabel = "z (cm)", ylabel = "Electron temperature (eV)")
	lines!(ax1, z_cm, avg_interactive.frames[].Tev)
	vlines!(ax1, [L_slider * 100], color = :gray, linestyle = :dash)

	ax2 = Axis(fig[2, 1], xlabel = "z (cm)", ylabel = "Electric field (V/m)")
	lines!(ax2, z_cm, avg_interactive.frames[].E)
	vlines!(ax2, [L_slider * 100], color = :gray, linestyle = :dash, label = "channel exit")
	axislegend(ax2)

	fig
end

# ╔═╡ 4ba1dbef-1091-4fd2-a776-e8cd87a08710
md"""
Check whether the electron-temperature peak and the main electric-field drop sit **inside** the dashed line (channel exit) — if the acceleration/ionization zone has drifted outside the channel, that is usually a sign this geometry/B-field combination needs retuning (and often correlates with higher wall erosion risk) [doc1][doc2].

"""

# ╔═╡ 78bbc571-9216-478c-93d3-a155505b14dd
md"""
## 5. Running a 1D geometry sweep

Now automate what you were just doing by hand: sweep channel length at fixed radii and collect performance metrics for each case.

"""

# ╔═╡ b4c19983-b5fb-4330-8faf-388b21d498c1
begin
	lengths_sweep = (1.5:0.5:4.0) .* u"cm"
	results_length = NamedTuple[]

	for L in lengths_sweep
		thr = build_thruster(L, 0.0345u"m", 0.05u"m"; name = "L=$(L)")
		cfg = make_config(thr)
		sp  = het.SimParams(grid = het.EvenGrid(100), dt = 5u"ns", duration = 500u"μs", num_save = 200)

		sol = het.run_simulation(cfg, sp)
		avg = het.time_average(sol, 250u"μs")

		push!(results_length, (
			L      = ustrip(u"m", L),
			thrust = het.thrust(avg)[],
			Id     = het.discharge_current(avg)[],
			eta_a  = het.anode_eff(avg)[],
			retcode = sol.retcode,
		))
	end

	results_length
end

# ╔═╡ 4fabe4ab-7abb-4d20-9100-40a012e66632
let
	good = filter(r -> r.retcode == :success, results_length)  # drop failed/unstable cases [doc1]

	fig = Figure(size = (500, 450))
	ax1 = Axis(fig[1, 1], xlabel = "Channel length (m)", ylabel = "Thrust (N)")
	lines!(ax1, [r.L for r in good], [r.thrust for r in good])
	scatter!(ax1, [r.L for r in good], [r.thrust for r in good])

	ax2 = Axis(fig[2, 1], xlabel = "Channel length (m)", ylabel = "Anode efficiency")
	lines!(ax2, [r.L for r in good], [r.eta_a for r in good])
	scatter!(ax2, [r.L for r in good], [r.eta_a for r in good])

	fig
end

# ╔═╡ 9f1a2b3c-4d5e-6f7a-8b9c-0d1e2f3a4b5c
begin
	good_summary = filter(r -> r.retcode == :success, results_length)
	if !isempty(good_summary)
		best = argmax(r -> r.eta_a, good_summary)
		md"""
		**Best case in this 1D sweep (by anode efficiency):**
		- Channel length: $(round(best.L, digits=4)) m
		- Thrust: $(round(best.thrust, digits=5)) N
		- Discharge current: $(round(best.Id, digits=3)) A
		- Anode efficiency: $(round(best.eta_a, digits=3))
		"""
	else
		md"*(No successful cases in this sweep.)*"
	end
end

# ╔═╡ d684185d-c0f3-499b-8ef6-2071f33a6244
md"""
## 6. Interactive 2D sweep: length × width

For a fuller trade study, sweep two variables at once — channel length and channel width (`r_out - r_in`) at a fixed mean radius. Use the sliders to pick the ranges, then run.

"""

# ╔═╡ e056452d-cebe-41ad-a321-5cb8a486f73b
@bind run_2d_sweep PlutoUI.CheckBox(default = false)

# ╔═╡ e1905572-8fdb-4053-9bb8-0eaa495df00f
md"Check the box above to run the 2D sweep (this executes more simulations and will take longer)."

# ╔═╡ b751ebdb-c35b-41ae-9a11-aa56e800886f
begin
	if run_2d_sweep
		r_mean    = 0.0425u"m"
		lengths_2d = (1.5:1.0:3.5) .* u"cm"
		widths_2d  = (0.01:0.005:0.025) .* u"m"

		results_2d = NamedTuple[]
		for L in lengths_2d, w in widths_2d
			r_in  = r_mean - w/2
			r_out = r_mean + w/2
			thr = build_thruster(L, r_in, r_out)
			cfg = make_config(thr)
			sp  = het.SimParams(grid = het.EvenGrid(80), dt = 5u"ns", duration = 400u"μs", num_save = 150)

			sol = het.run_simulation(cfg, sp)
			avg = het.time_average(sol, 200u"μs")

			push!(results_2d, (
				L = ustrip(u"m", L),
				w = ustrip(u"m", w),
				thrust = het.thrust(avg)[],
				eta_a  = het.anode_eff(avg)[],
				retcode = sol.retcode,
			))
		end
		results_2d
	else
		md"*(2D sweep not run — check the box above.)*"
	end
end

# ╔═╡ 1fe7d2e6-b092-4e52-8b85-db4c0ffb79ca
if run_2d_sweep
	good2d = filter(r -> r.retcode == :success, results_2d)

	fig = Figure(size = (500, 400))
	ax = Axis(fig[1, 1], xlabel = "Channel length (m)", ylabel = "Channel width (m)",
		title = "Anode efficiency across length × width")
	sc = scatter!(ax, [r.L for r in good2d], [r.w for r in good2d],
		color = [r.eta_a for r in good2d], colormap = :viridis, markersize = 20)
	Colorbar(fig[1, 2], sc, label = "Anode efficiency")
	fig
else
	md"*(Run the 2D sweep above to see this plot.)*"
end

# ╔═╡ 3693fad1-8f7a-4482-b925-bca2ccea8ced
md"""
## 7. Interpreting the trade space

| Geometry change | Expected effect |
|---|---|
| Longer channel (fixed flow rate, voltage) | More complete ionization (higher mass utilization) up to a point, then diminishing returns and higher wall losses as residence time near the wall increases |
| Wider channel (fixed mean radius) | Lower current density, lower wall erosion rate, often lower current utilization efficiency unless B-field and wall material are retuned |
| Larger mean radius (fixed width) | Higher channel area → can run higher mass flow rate for same current density → higher thrust, but larger mass/volume |
| B-field peak not aligned with channel exit | Voltage utilization efficiency drops — acceleration zone leaks into plume or sits upstream of the exit |

Because anode efficiency combines mass, current, and voltage utilization [doc2], a geometry that wins on thrust alone can still be a poor design if that thrust is propped up by one efficiency term while another collapses. Always check the breakdown (§4 table), not just thrust.

"""

# ╔═╡ ec0ca50f-174b-4b7b-8fdf-93eefdd9b34a
md"""
## 8. Practical tips specific to geometry studies

- **Re-derive the magnetic field for every geometry.** Don't reuse a fixed field profile across different channel lengths — the `build_thruster` function above re-scales it automatically; if you swap in your own field model, keep that coupling [doc1][doc2].
- **Keep the domain large enough** relative to the longest channel length in your sweep, or you'll truncate plume physics.
- **Watch `retcode`.** A sweep will occasionally produce `:failure` or `:error` (numerical instability from an extreme geometry/B-field combination). The filters in §5–6 (`retcode == :success`) drop these — treat them as a sign the combination is physically unrealistic, not something to silently ignore [doc1].
- **Use an explicit `wall_loss_model`** (e.g. `WallSheath(BoronNitride)`) when comparing channel widths — wall interactions scale with surface-to-volume ratio and are central to any geometry trade [doc2][doc3].
- **Checkpoint with `write_restart`/`read_restart`** for larger sweeps so you can resume longer, finer runs on your best candidates without rerunning everything [doc2].
- **Coarse screen, then verify.** This notebook uses a small grid (`EvenGrid(80–100)`) and short `duration` for interactive speed. Once you've picked a promising region of geometry space, rerun the top candidates with a finer grid (`UnevenGrid`, more cells) and longer duration for trustworthy numbers [doc1].

"""

# ╔═╡ 3a6e5f3e-a192-461a-ae11-2901062032c0
md"""
## 9. Where to go next

- [Configuration reference](https://um-pepl.github.io/HallThruster.jl/dev/reference/config/) — every `Config` option, including wall loss and anomalous transport models [doc3].
- [Grid generation](https://um-pepl.github.io/HallThruster.jl/dev/explanation/grid_generation/) — `EvenGrid` vs `UnevenGrid` for refining your final candidates.
- [Wall Loss Models](https://um-pepl.github.io/HallThruster.jl/dev/reference/wall_loss_models/) — directly relevant since wall losses scale with geometry.
- [Thrusters reference](https://um-pepl.github.io/HallThruster.jl/dev/reference/thrusters/) — full `Geometry1D`, `MagneticField`, and `Thruster` API.

Citation: Marks, Schedler, and Jorns, *"HallThruster.jl: a Julia package for 1D Hall thruster discharge simulation,"* Journal of Open Source Software, 8(86), 4672 (2023) [doc5].

"""

# ╔═╡ Cell order:
# ╠═53b0d087-954b-408e-8b3f-86fc9ff1742e
# ╠═a8da3bc7-fd7d-4a51-af24-efe372a6e93d
# ╠═253088a2-1fb9-48f3-9e44-7ddd2de9ef4d
# ╠═4cbbd0a8-897c-4525-80f6-f862cd8ea295
# ╠═81434d76-d0be-4769-92d2-06051ac80c49
# ╠═66186ef2-ced0-46a9-9981-cacf5b494688
# ╠═b4bcf506-d8e7-43da-919c-8b33ccdd08a6
# ╠═9ac340d5-8b60-403e-8b68-3df8f3c47cd4
# ╠═d4f67adc-2c38-4e00-bc90-c5bfe8f365e1
# ╠═530bec76-36ef-486f-a664-9d546fa31698
# ╠═f59d8c15-3b52-4a40-b01e-1fc90f5bea1f
# ╠═db45a324-b8d8-4ee1-94a2-89fe76fe7f65
# ╠═b9a1795b-7265-4851-aa5e-725d3e9506e9
# ╠═11f3ca8c-bc1d-4340-87cb-dd5cf780fca5
# ╠═ed0f779a-777d-4d6d-94ef-0413239c1fa1
# ╠═fc8477c1-dbfc-44f8-a101-4ff5c98c17e2
# ╠═abf1ad3b-54c2-49e0-a8d4-33d2cde840e9
# ╠═4ba1dbef-1091-4fd2-a776-e8cd87a08710
# ╠═78bbc571-9216-478c-93d3-a155505b14dd
# ╠═b4c19983-b5fb-4330-8faf-388b21d498c1
# ╠═4fabe4ab-7abb-4d20-9100-40a012e66632
# ╠═d684185d-c0f3-499b-8ef6-2071f33a6244
# ╠═e056452d-cebe-41ad-a321-5cb8a486f73b
# ╠═e1905572-8fdb-4053-9bb8-0eaa495df00f
# ╠═b751ebdb-c35b-41ae-9a11-aa56e800886f
# ╠═1fe7d2e6-b092-4e52-8b85-db4c0ffb79ca
# ╠═3693fad1-8f7a-4482-b925-bca2ccea8ced
# ╠═ec0ca50f-174b-4b7b-8fdf-93eefdd9b34a
# ╠═3a6e5f3e-a192-461a-ae11-2901062032c0

