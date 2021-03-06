abstract type UnobservedEffectsModel <: StatsBase.RegressionModel end

struct UnobservedEffectsModelExogenous <: UnobservedEffectsModel
	model_stats::Dict{Symbol, ModelValues}
end
struct UnobservedEffectsModelEndogenous <: UnobservedEffectsModel
	model_stats::Dict{Symbol, ModelValues}
end
function uem(estimator::Symbol, fm::StatsModels.Formula, df::DataFrames.DataFrame; PID::Symbol = names(df)[1], TID::Symbol = names(df)[2], contrasts = Dict{Symbol, StatsModels.ContrastsMatrix}(),
	effect::Symbol = :Panel)
	@assert (effect in [:Panel, :Temporal, :TwoWays]) "Effect must be either:\n
	Panel, Temporal or TwoWays."
	if (estimator == :RE)
		@assert (effect == :Panel) "Random Effects is only implemented as a one-way error component for panels."
	elseif (estimator == :FD)
		@assert (effect == :Panel) "First-Difference is only defined for panel effects."
	elseif (estimator != :FE)
		@assert (effect != :TwoWays) "Two-Ways Effects are only implemented for Fixed Effects."
	end
	estimator = getEstimator(estimator)
	Terms = StatsModels.Terms(fm)
	Intercept = getfield(Terms, :intercept)
	if isa(estimator, RE)
		@assert Intercept "Random Effects model requires an intercept."
	end
	rhs = allvars(getfield(fm, :rhs))
	df, PID, TID = PreModelFrame(fm, df, PID, TID)
	mf = StatsModels.ModelFrame(fm, df, contrasts = contrasts)
	varlist = StatsBase.coefnames(mf)
	X = getfield(StatsModels.ModelMatrix(mf), :m)
	y = Vector{Float64}(df[fm.lhs])
	if Intercept
		Categorical = Vector{Bool}([false])
	else
		Categorical = Vector{Bool}()
	end
	for idx in eachindex(rhs)
		tmp = DataFrames.is_categorical(df[rhs[idx]])
		if tmp
			tmp = repeat([true], inner = length(unique(df[rhs[idx]])) - 1)
		end
		for each in tmp
			push!(Categorical, each)
		end
	end
	PID, TID, X, Bread, y, β, varlist, ŷ, û, nobs, N, n, T, mdf, rdf, RSS, MRSS, individual, idiosyncratic, θ =
		build_model(estimator, PID, TID, effect, X, y, varlist, Categorical, Intercept)
	R² = ModelValues_R²(y, RSS)
	estimator = ModelValues_Estimator(estimator)
	Intercept = ModelValues_Intercept(Intercept)
	fm = ModelValues_Formula(fm)
	Effect = ModelValues_Effect(String(effect))
	chk = [(:X, X), (:y, y), (:Bread, Bread), (:β, β), (:ŷ, ŷ), (:û, û), (:RSS, RSS), (:mdf, mdf), (:rdf, rdf), (:MRSS, MRSS), (:R², R²), (:nobs, nobs), (:N, N), (:n, n), (:Formula, fm), (:Estimator, estimator), (:Varlist, varlist), (:PID, PID), (:TID, TID), (:Effect, Effect), (:idiosyncratic, idiosyncratic), (:individual, individual), (:θ, θ), (:Intercept, Intercept), (:T, T)]
	# for each in chk
	# 	println(typeof(last(each)))
	# end
	model_stats = Dict{Symbol, ModelValues}(chk)
	UnobservedEffectsModelExogenous(model_stats)
end
function uem(estimator::Symbol, fm::StatsModels.Formula, iv::StatsModels.Formula, df::DataFrames.DataFrame; PID::Symbol = names(df)[1], TID::Symbol = names(df)[2], contrasts = Dict{Symbol, StatsModels.ContrastsMatrix}(),
	effect::Symbol = :Panel)
	@assert (effect in [:Panel, :Temporal, :TwoWays]) "Effect must be either:\n
	Panel, Temporal or TwoWays"
	if (estimator == :RE)
		@assert (effect == :Panel) "Random Effects is only implemented as a one-way error component for panels."
	elseif (estimator == :FD)
		@assert (effect == :Panel) "First-Difference is only defined for panel effects."
	elseif (estimator != :FE)
		@assert (effect != :TwoWays) "Two-Ways Effects are only implemented for Fixed Effects."
	end
	estimator = getEstimator(estimator)
	Terms = StatsModels.Terms(fm)
	Intercept = getfield(Terms, :intercept)
	if isa(estimator, RE)
		@assert Intercept "Random Effects model requires an intercept."
	end
	rhs = allvars(getfield(fm, :rhs))
	rhsIV = allvars(getfield(iv, :rhs))
	df, PID, TID = PreModelFrame(fm, iv, df, PID, TID)
	mf = StatsModels.ModelFrame(fm, df, contrasts = contrasts)
	varlist = vcat(StatsBase.coefnames(mf), string.(allvars(iv.lhs)))
	X = getfield(StatsModels.ModelMatrix(mf), :m)
	z = Matrix(df[:,allvars(iv.lhs)])
	iv_formula = StatsModels.Formula(allvars(iv.lhs)[1], iv.rhs)
	Z = StatsModels.ModelFrame(iv_formula, df, contrasts = contrasts)
	Z = getfield(StatsModels.ModelMatrix(Z), :m)
	Z = Z[:,2:end]
	y = Vector{Float64}(df[fm.lhs])
	if Intercept
		Categorical = Vector{Bool}([false])
	else
		Categorical = Vector{Bool}()
	end
	for idx in eachindex(rhs)
		tmp = DataFrames.is_categorical(df[rhs[idx]])
		if tmp
			tmp = repeat([true], inner = length(unique(df[rhs[idx]])) - 1)
		end
		for each in tmp
			push!(Categorical, each)
		end
	end
	CategoricalIV = Vector{Bool}()
	for idx in eachindex(rhsIV)
		tmp = DataFrames.is_categorical(df[rhsIV[idx]])
		if tmp
			tmp = repeat([true], inner = length(unique(df[rhsIV[idx]])) - 1)
		end
		for each in tmp
			push!(CategoricalIV, each)
		end
	end
	PID, TID, X, Bread, y, β, varlist, ŷ, û, nobs, N, n, T, mdf, rdf, RSS, MRSS, individual, idiosyncratic, θ =
		build_model(estimator, PID, TID, effect, X, z, Z, y, varlist, Categorical, CategoricalIV, Intercept)
	estimator = ModelValues_Estimator(estimator)
	Intercept = ModelValues_Intercept(Intercept)
	fm = ModelValues_Formula(fm)
	iv = ModelValues_Formula(iv)
	Effect = ModelValues_Effect(String(effect))
	chk = [(:X, X), (:y, y), (:Bread, Bread), (:β, β), (:ŷ, ŷ), (:û, û), (:RSS, RSS), (:mdf, mdf), (:rdf, rdf), (:MRSS, MRSS), (:nobs, nobs), (:N, N), (:n, n), (:Formula, fm), (:iv, iv), (:Estimator, estimator), (:Varlist, varlist), (:PID, PID), (:TID, TID), (:Effect, Effect), (:idiosyncratic, idiosyncratic), (:individual, individual), (:θ, θ), (:Intercept, Intercept), (:T, T)]
	# for each in chk
	# 	println(typeof(last(each)))
	# end
	model_stats = Dict{Symbol, ModelValues}(chk)
	UnobservedEffectsModelEndogenous(model_stats)
end
