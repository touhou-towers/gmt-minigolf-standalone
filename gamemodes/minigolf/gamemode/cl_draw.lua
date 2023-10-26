local lasermat = Material("effects/laser1.vmt")
local wire = Material("models/wireframe.vmt")
local color = Material("color.vmt")
local arrow = Material("vgui/gradient_up.vmt")
local sprite = Material("sprites/powerup_effects")
local putter = Model("models/gmod_tower/putter.mdl")

Debug = false -- DEBUG

RenderUTIL = {}

RenderUTIL.renderLine = function(startpos, endpos, thickness, color)
	render.SetMaterial(lasermat)
	render.DrawBeam(startpos, endpos, thickness or 8, 0, 1, color or Color(255, 255, 255, 255))
	render.SetMaterial(sprite)
	render.DrawSprite(startpos, thickness * 2, thickness * 2, color or Color(255, 255, 255, 255))
end

RenderUTIL.renderReflection = function(hit, aimvec, normal, thickness, color)
	local reflect = aimvec - (normal:Dot(aimvec)) * normal * 2
	local endpos = hit - reflect * 100

	if normal ~= Vector(0, 0, 0) then
		DrawLine(hit, endpos, thickness, color)
	end
end

RenderUTIL.renderBox = function(pos, min, max, bcolor)
	render.SetMaterial(color)
	render.DrawBox(pos, Angle(0, 0, 0), min, max, bcolor or Color(255, 255, 255, 255))
end

RenderUTIL.renderPlane = function(pos, normal, width, height, bcolor)
	local vec = normal:Angle()

	render.SetMaterial(color)
	render.DrawBox(pos, vec, Vector(0, -width, -height), Vector(0.01, width, height), bcolor or Color(0, 0, 255, 150))
end

RenderUTIL.renderArrowOnPlane = function(pos, normal, dir, width, height, bcolor)
	local vec = normal:Angle() + Angle(0, 0, 180)

	vec:RotateAroundAxis(normal, dir)
	pos = pos + vec:Up() * height

	render.SetMaterial(arrow)
	render.DrawBox(pos, vec, Vector(0, -width, -height), Vector(0.01, width, height), bcolor or Color(255, 0, 0, 255))
end

RenderUTIL.renderAxis = function(pos, vec)
	vec = vec:Angle()

	render.SetMaterial(color)
	render.DrawBox(pos, vec, Vector(0, -0.2, -0.2), Vector(6, 0.2, 0.2), Color(0, 0, 255, 255))
	render.DrawBox(pos, vec, Vector(-0.2, -0.2, 0), Vector(0.2, 0.2, 6), Color(255, 0, 0, 255))
	render.DrawBox(pos, vec, Vector(-0.2, 0, -0.2), Vector(0.2, 6, 0.2), Color(0, 255, 0, 255))
end

RenderUTIL.renderPutter = function(draw, ball)
	if draw then
		if not IsValid(Putter) then
			Putter = ClientsideModel(putter)
		end

		local normal = RenderSettings.aimplane
		local dir = RenderSettings.direction
		local dist = math.Clamp((Swing.power / 5), 5, 40)

		-- Animate the swing
		if LocalPlayer().Swung then
			dist = 2
		end

		if not PutterDist then
			PutterDist = dist
		end

		PutterDist = math.Approach(PutterDist, dist, FrameTime() * 120)

		local vec = normal:Angle() + Angle(90, 90, PutterDist / 3)
		vec:RotateAroundAxis(normal, dir)
		-- vec.p = 0

		local color = LocalPlayer():GetBallColor() * 255

		Putter:SetColor(Color(color.r, color.g, color.b, 255))
		Putter:SetPos(ball:GetPos() + Vector(0, 0, -72) + vec:Right() * -PutterDist)
		Putter:SetRenderAngles(vec)
		Putter:SetModelScale(1.75, 0)
		Putter:DrawModel()
	else
		if IsValid(Putter) then
			Putter:Remove()
			Putter = nil
		end
	end
end

local function DrawMinigolf(ball)
	if IsValid(ball) and LocalPlayer():CanPutt() and Swing.power > 0 then
		local color = LocalPlayer():GetBallColor() * 255

		RenderUTIL.renderArrowOnPlane(
			RenderSettings.target,
			RenderSettings.aimplane,
			RenderSettings.direction,
			RenderSettings.arWidth,
			RenderSettings.arHeight,
			Color(color.r, color.g, color.b)
		)
	end
end

function GM:PostDrawTranslucentRenderables()
	local ball = LocalPlayer():GetGolfBall()

	if IsValid(ball) then
		local trace = ball:GetDownTrace()

		if trace.Entity and not trace.HitWorld then
			DrawMinigolf(ball)
		end
	end
end

function GM:PreDrawTranslucentRenderables()
	local ball = LocalPlayer():GetGolfBall()

	if IsValid(ball) then
		local trace = ball:GetDownTrace()

		if trace.HitWorld then
			DrawMinigolf(ball)
		end
	end
end

if not Debug then
	return
end

hook.Add(
	"PostDrawHalos",
	"BallHalo",
	function()
		local ball = LocalPlayer():GetGolfBall()

		if IsValid(ball) then
			local color = LocalPlayer():GetBallColor() * 255

			halo.Add({ball}, Color(color.r, color.g, color.b), 3, 3, 1, true, true)
		end
	end
)

function GM:PostDrawTranslucentRenderables()
	local ball = LocalPlayer():GetGolfBall()

	if IsValid(ball) and LocalPlayer():CanPutt() and Swing.power > 0 then
		RenderUTIL.renderPutter(true, ball)
	else
		RenderUTIL.renderPutter(false)
	end

	if IsValid(ball) then
		local origin = ball:GetPos()
		local vel = ball:GetVelocity()

		vel.z = 0

		local trace =
			util.TraceLine(
			{
				start = origin,
				endpos = origin + vel,
				filter = {ball}
			}
		)

		if trace.HitPos then
			RenderUTIL.renderLine(origin, trace.HitPos, 2)

			local radius = 1

			RenderUTIL.renderBox(trace.HitPos, Vector(-radius, -radius, -radius), Vector(radius, radius, radius))

			-- Reflection
			local aimvec = (origin - trace.HitPos):GetNormal()
			local normal = trace.HitNormal
			local reflect = aimvec - (normal:Dot(aimvec)) * normal * 2
			local endpos = trace.HitPos - reflect * 100

			if normal ~= Vector(0, 0, 0) then
				RenderUTIL.renderLine(trace.HitPos, endpos, 2)
				RenderUTIL.renderBox(endpos, Vector(-radius, -radius, -radius), Vector(radius, radius, radius))
			end
		end
	end

	RenderUTIL.renderPlane(RenderSettings.target, RenderSettings.aimplane, RenderSettings.pWidth, RenderSettings.pHeight)

	-- Manage the power color

	-- Bounding box
	local radius = ball.Radius

	Debug3D.DrawBox(
		ball:GetPos() + Vector(-radius, -radius, -radius),
		ball:GetPos() + Vector(radius, radius, radius),
		color
	)
end
