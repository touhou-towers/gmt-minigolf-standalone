include("camsystem/cl_init.lua")
include("camsystem/shared.lua")
include("Catmull/shared.lua")

include("cl_camera.lua")
include("cl_controls.lua")
include("cl_draw.lua")
include("cl_hud.lua")
include("cl_hud_customize.lua")
include("cl_music.lua")
include("cl_scorecard.lua")

include("gmt/camera/" .. game.GetMap() .. ".lua")

include("meta_camera.lua")
include("meta_player.lua")

include("sh_move.lua")
include("sh_scores.lua")
include("shared.lua")
include("cl_scoreboard.lua")
include("sh_payout.lua")

ConVarDisplayHUD = CreateClientConVar("mg_hud", 1, true)
ConVarDrawBlur = CreateClientConVar("mg_blur", 1, true)
-- ConVarDLights = CreateClientConVar( "mg_dlights", 2, true )

hook.Add(
	"InitPostEntity",
	"SetDetail",
	function()
		if tonumber(LocalPlayer():GetInfo("cl_detaildist")) > 500 then
			RunConsoleCommand("cl_detaildist", 500)
		end
	end
)

function GM:ChatBubbleOverride(ply)
	if not IsValid(ply) then
		return false
	end

	local ball = ply:GetGolfBall()

	if IsValid(ball) and ball:GetOwner() == ply then
		return ball:GetPos() + Vector(0, 0, 25)
	end

	return false
end

hook.Add(
	"PositionHatOverride",
	"OverrideHatBall",
	function(ent, data, pos, ang, scale)
		if ent:GetClass() == "golfball" then
			if ent.CurAngle then
				ang = ent.CurAngle
			else
				ang = Angle(0, 0, 0)
			end

			if ent:GetVelocity():Length() > 10 then
				local vec = ent:GetVelocity():Angle()
				ang = vec
				ent.CurAngle = ang
			end

			local z = data[1]
			pos = ent:GetPos() + Vector(0, 0, z)

			return pos, ang, scale
		end
	end
)

hook.Add(
	"HUDPaint",
	"ToyTownEffect",
	function()
		if not ConVarDrawBlur:GetBool() then
			return
		end
		if not render.SupportsPixelShaders_2_0() then
			return
		end

		local NumPasses = 3
		local H = ScrH() * .2

		DrawToyTown(NumPasses, H)
	end
)

hook.Add(
	"Think",
	"LateJoinCameraDefault",
	function()
		if GAMEMODE:GetState() == STATE_WAITING then
			camsystem.LateJoinCamera = "Waiting"
		end

		if GAMEMODE:IsPlaying() then
			camsystem.LateJoinCamera = "Playing"
		end
	end
)

function GM:Think()
	-- Scoreboard.Customization.PlayerActionBoxEnabled = !( self:GetState() == STATE_WAITING || self:GetState() == STATE_SETTINGS )
	vgui.GetWorldPanel():SetCursor("default")
	self:FadeBrushes()
end

function GM:FadeBrushes()
	-- Preform fade
	local entities = ents.FindByClass("func_brush")
	entities = table.Add(entities, ents.FindByClass("func_rotating"))

	for _, ent in pairs(entities) do
		if not ent.Alpha then
			ent.Alpha = 255
		end

		if ent.ShouldFade then
			ent.Alpha = math.Approach(ent.Alpha, 150, 4)
		else
			ent.Alpha = math.Approach(ent.Alpha, 255, 4)
		end

		ent:SetColor(Color(255, 255, 255, ent.Alpha))
		ent:SetRenderMode(RENDERMODE_TRANSALPHA)
		ent.ShouldFade = false
	end

	local ball = LocalPlayer():GetGolfBall()

	if IsValid(LocalPlayer().Spectating) then
		ball = LocalPlayer().Spectating:GetGolfBall()
	end

	if IsValid(ball) then
		local trace = util.TraceLine({start = ball:GetPos(), endpos = LocalPlayer().CameraPos, filter = ball})
		local balltrace = ball:GetDownTrace()

		if IsValid(trace.Entity) then
			if
				IsValid(balltrace.Entity) and (balltrace.Entity == trace.Entity) and balltrace.Entity:GetClass() ~= "func_rotating"
			 then
				return
			end -- Don't fade the object the ball is on
			trace.Entity.ShouldFade = true
		end
	end
end

local PANEL = {}

RADIAL_ALIGN_NONE = 0
RADIAL_ALIGN_SPATIAL = 1
RADIAL_ALIGN_CENTER = 2

AccessorFunc(PANEL, "m_bDrawDebug", "PaintDebug")
AccessorFunc(PANEL, "m_iRadiusScale", "RadiusScale")
AccessorFunc(PANEL, "m_iRadiusPadding", "RadiusPadding")
AccessorFunc(PANEL, "m_iDegreeOffset", "DegreeOffset")
AccessorFunc(PANEL, "m_iAlignMode", "AlignMode")
AccessorFunc(PANEL, "m_bAllowInput", "AllowInput")

function PANEL:Init()
	self.Items = {}

	self.TotalRadians = 0
	self.LastDeg = 0

	self:SetRemoveOnSelect(true)
	self:SetPaintDebug(false)
	self:SetRadiusPadding(0)
	self:SetRadiusScale(1.0)
	self:SetDegreeOffset(0)
	self:SetAlignMode(RADIAL_ALIGN_SPATIAL)
	self:SetAllowInput(true)

	self:SetMouseInputEnabled(true)

	self:SetDrawBackground(true)
	self:SetPaintBackgroundEnabled(false)
	self:SetPaintBorderEnabled(false)
	self:SetPaintSelectColor(Color(255, 255, 255, 150))
end

--[[---------------------------------------------------------
	Paint
-----------------------------------------------------------]]
function PANEL:Paint(w, h)
	if #self.Items == 0 then
		return
	end

	if self:GetPaintDebug() then
		self:PaintDebug(w, h)
	end

	if vgui.CursorVisible() and ValidPanel(self.Selected) then
		self:PaintSelected(self.Selected, w, h, self.PaintSelectColor, true)
	end

	if self.Save and ValidPanel(self.SaveSelected) then
		self:PaintSelected(self.SaveSelected, w, h, self.PaintSaveSelectColor)
	end
end

local texture = surface.GetTextureID("vgui/gradient_down")
local intensity = 0.66
local realdeg, vertices, x, y, r
function PANEL:PaintSelected(selected, w, h, color, ease)
	x, y = self:GetCenterPosLocal()
	realdeg = selected and selected.ang or 0

	local deg = (ease and self.LastPaintDeg) or realdeg

	if not vertices then
		vertices = {}
		vertices[1] = {x = x, y = y, u = 1, v = 1}
		vertices[2] = {x = x, y = y, u = intensity, v = intensity}
		vertices[3] = {x = x, y = y, u = intensity, v = intensity}
	end

	r = self:GetRadius()
	vertices[2].x = x + (r * math.cos(math.rad(deg - 15)))
	vertices[2].y = y + (r * math.sin(math.rad(deg - 15)))
	vertices[3].x = x + (r * math.cos(math.rad(deg + 15)))
	vertices[3].y = y + (r * math.sin(math.rad(deg + 15)))

	surface.SetTexture(texture)
	surface.SetDrawColor(color)
	surface.DrawPoly(vertices)

	-- surface.SetDrawColor(255,255,255,255) -- So it draws in normal color.
	-- surface.DrawTexturedRectRotated(w/2, h/2, self:GetRadius(), self:GetRadius(), deg)

	local diff = math.abs(math.AngleDifference(realdeg, deg))
	if ease then
		self.LastPaintDeg = math.ApproachAngle(deg, realdeg, diff * 0.35) % 360
	end
end

function PANEL:SetPaintSelectColor(color)
	self.PaintSelectColor = color
end

function PANEL:SetPaintSaveSelectColor(color)
	self.PaintSaveSelectColor = color
end

function PANEL:SetSave(bool)
	self.Save = bool
end

function PANEL:PaintDebug(w, h)
	local rw = ((w / 2) - self:GetRadiusPadding()) * self:GetRadiusScale()
	local rh = ((h / 2) - self:GetRadiusPadding()) * self:GetRadiusScale()

	local CurDeg = self:GetRadianOffset()
	if self:GetAlignMode() == RADIAL_ALIGN_CENTER then
		CurDeg = CurDeg - self.TotalRadians / 2
	end

	local x, y = w / 2, h / 2

	for _, p in pairs(self.Items) do
		surface.SetDrawColor(Color(0, 0, 255))

		-- Start
		local x2, y2 = rw * math.cos(CurDeg), rh * math.sin(CurDeg)
		surface.DrawLine(x, y, x + x2, y + y2)

		-- End
		local deg = p.theta
		if self:GetAlignMode() == RADIAL_ALIGN_SPATIAL then
			deg = 2 * math.pi / #self.Items
		end

		CurDeg = CurDeg + deg
		x2, y2 = rw * math.cos(CurDeg), rh * math.sin(CurDeg)
		surface.DrawLine(x, y, x + x2, y + y2)

		-- Midpoint
		surface.SetDrawColor(Color(0, 255, 0, 100))
		local deg2 = deg / 2
		x2, y2 = rw * math.cos(CurDeg - deg2), rh * math.sin(CurDeg - deg2)
		surface.DrawLine(x, y, x + x2, y + y2)
	end

	if vgui.CursorVisible() then
		-- TODO: fix this for panel not taking up screen
		local x, y = self:LocalCursorPos()
		surface.DrawLine(w / 2, h / 2, x, y)
	end
end

--[[---------------------------------------------------------
	Position Helper Functions
-----------------------------------------------------------]]
function PANEL:LocalCursorToCenter()
	local w, h = self:GetSize()
	local x, y = self:LocalCursorPos()

	x = x - (w / 2)
	y = y - (h / 2)

	return x, y
end

function PANEL:GetCenterPos()
	local w, h = self:GetSize()
	local x, y = self:GetPos()

	x = x + (w / 2)
	y = y + (h / 2)

	return x, y
end

function PANEL:GetCenterPosLocal()
	local w, h = self:GetSize()
	return w / 2, h / 2
end

function PANEL:GetCursorAngle()
	if not vgui.CursorVisible() then
		return 0
	end

	local x, y = self:LocalCursorToCenter()
	return math.atan2(y, x)
end

--[[---------------------------------------------------------
   Radian Offset
-----------------------------------------------------------]]
function PANEL:SetRadianOffset(rads)
	self:SetDegreeOffset(math.deg(rads))
end

function PANEL:GetRadianOffset()
	return math.rad(self:GetDegreeOffset())
end

--[[---------------------------------------------------------
   Radius
-----------------------------------------------------------]]
function PANEL:GetRadius()
	local w, h = self:GetSize()
	local rw = ((w / 2) - self:GetRadiusPadding()) * self:GetRadiusScale()
	local rh = ((h / 2) - self:GetRadiusPadding()) * self:GetRadiusScale()

	return math.sqrt(rw ^ 2 + rh ^ 2)
end

--[[---------------------------------------------------------
   Selected Item
-----------------------------------------------------------]]
function PANEL:SetSelected(panel, ang)
	if ValidPanel(self.Selected) then
		if self.Selected == panel then
			return
		end

		self.Selected.Hovered = false
		self.LastSelected = nil
	end

	self.Selected = panel
	self.Selected.Hovered = true
end

function PANEL:SetSaveSelected(panel)
	local w, h = self:GetSize()
	local CurRad = self:GetRadianOffset()

	if self:GetAlignMode() == RADIAL_ALIGN_CENTER then
		CurRad = CurRad - self.TotalRadians / 2
	end

	local x, y = w / 2, h / 2
	local rad

	for _, p in pairs(self.Items) do
		-- Find end radians
		rad = p.theta or 0.33

		if self:GetAlignMode() == RADIAL_ALIGN_SPATIAL then
			rad = 2 * math.pi / #self.Items
		end

		local target = math.deg(CurRad + (rad / 2))

		if panel == p then
			panel.ang = target
		end

		CurRad = CurRad + rad
	end

	self.SaveSelected = panel
end

function PANEL:GetSelected()
	return self.Selected
end

function PANEL:CheckSelected()
	local w, h = self:GetSize()
	-- local ang = self:GetCursorAngle()
	local ang = math.rad(self.LastDeg)

	-- Find the closest panel

	local rw = ((w / 2) - self:GetRadiusPadding()) * self:GetRadiusScale()
	local rh = ((h / 2) - self:GetRadiusPadding()) * self:GetRadiusScale()

	local CurRad = self:GetRadianOffset()

	if self:GetAlignMode() == RADIAL_ALIGN_CENTER then
		CurRad = CurRad - self.TotalRadians / 2
	end

	local x, y = w / 2, h / 2
	local selected, delta, rad

	for _, p in pairs(self.Items) do
		-- Find end radians
		rad = p.theta or 0.33

		if self:GetAlignMode() == RADIAL_ALIGN_SPATIAL then
			rad = 2 * math.pi / #self.Items
		end

		local source = math.deg(ang)
		local target = math.deg(CurRad + (rad / 2))
		local diff = math.abs(math.AngleDifference(source, target))

		if not delta or diff < delta then
			delta = diff
			selected = p
			selected.ang = target
		end

		CurRad = CurRad + rad
	end

	self:SetSelected(selected)
end

--[[---------------------------------------------------------
   Name: Think
-----------------------------------------------------------]]
function PANEL:Think()
	if not self:GetAllowInput() then
		return
	end

	-- Cursor think must be in think due
	-- to panels being above the menu
	self:CursorThink()

	local MouseDown = input.IsMouseDown(MOUSE_LEFT)

	if MouseDown and ValidPanel(self.Selected) then
		if self.Selected.DoClick then
			self.Selected:DoClick()
			self:SetSaveSelected(self.Selected)
		end

		if self.ShouldRemove then
			self:Remove()
			gui.EnableScreenClicker(false)
		end
	end
end

function PANEL:SetRemoveOnSelect(bool)
	self.ShouldRemove = bool
end

--[[---------------------------------------------------------
   Name: CursorThink
   Desc: Used for resetting cursor position when being
   forced to select an item
-----------------------------------------------------------]]
function PANEL:CursorThink()
	-- Ignore checking menu while user is outside of the game
	if not system.HasFocus() then
		return
	end

	-- Get offset local to radial menu's center
	local x, y = self:LocalCursorToCenter()

	-- Ignore movements of small magnitudes
	local len = math.sqrt(x ^ 2 + y ^ 2)
	if len < 20 then
		return
	end

	-- Approach desired selection angle
	local ang = math.deg(self:GetCursorAngle())
	local diff = math.abs(math.AngleDifference(ang, self.LastDeg))
	self.LastDeg = math.ApproachAngle(self.LastDeg, ang, 50 * diff)
	self.LastDeg = math.NormalizeAngle(self.LastDeg)

	-- Old way of getting desired location
	-- self.LastDeg = math.deg(self:GetCursorAngle())

	self:CheckSelected()

	-- Reset cursor position to center
	-- local cx, cy = self:GetCenterPos()
	-- input.SetCursorPos(cx, cy)
end

--[[---------------------------------------------------------
   Name: PerformLayout
-----------------------------------------------------------]]
function PANEL:PerformLayout()
	if ValidPanel(self.CenterPanel) then
		self.CenterPanel:Center()
	end

	local w, h = self:GetSize()

	-- Find the closest panel

	local rw = ((w / 2) - self:GetRadiusPadding()) * self:GetRadiusScale()
	local rh = ((h / 2) - self:GetRadiusPadding()) * self:GetRadiusScale()

	local CurRad = self:GetRadianOffset()

	if self:GetAlignMode() == RADIAL_ALIGN_CENTER then
		CurRad = CurRad - self.TotalRadians / 2
	end

	local x, y = w / 2, h / 2
	local rad

	for _, p in pairs(self.Items) do
		-- Find end radians
		rad = p.theta
		if self:GetAlignMode() == RADIAL_ALIGN_SPATIAL then
			rad = 2 * math.pi / #self.Items
		end

		CurRad = CurRad + rad

		-- Midpoint
		surface.SetDrawColor(Color(0, 255, 0, 100))
		local rad2 = rad / 2
		local x2, y2 = rw * math.cos(CurRad - rad2), rh * math.sin(CurRad - rad2)

		local w2, h2 = p:GetSize()
		p:SetPos(x + x2 - w2 / 2, y + y2 - h2 / 2)
	end
end

--[[---------------------------------------------------------
   Name: SetCenterPanel
-----------------------------------------------------------]]
function PANEL:SetCenterPanel(panel)
	if not ValidPanel(panel) then
		return
	end

	panel:SetParent(self)
	self.CenterPanel = panel

	self:InvalidateLayout()
end
function PANEL:GetCenterPanel()
	return self.CenterPanel
end

--[[---------------------------------------------------------
   Name: AddItem
-----------------------------------------------------------]]
function PANEL:AddItem(panel, degrees)
	if not ValidPanel(panel) then
		return
	end

	panel.theta = math.rad(degrees or 35)
	self.TotalRadians = self.TotalRadians + panel.theta

	panel:SetVisible(true)
	panel:SetParent(self)

	table.insert(self.Items, panel)

	self:InvalidateLayout()
end

--[[---------------------------------------------------------
   Name: RemoveItem
-----------------------------------------------------------]]
function PANEL:RemoveItem(panel, bDontDelete)
	for k, panel in pairs(self.Items) do
		if (panel == item) then
			self.Items[k] = nil

			if (not bDontDelete) then
				panel:Remove()
			end

			self:InvalidateLayout()
		end
	end
end

--[[---------------------------------------------------------
   Name: Clear
-----------------------------------------------------------]]
function PANEL:Clear(bDelete)
	for k, panel in pairs(self.Items) do
		if (IsValid(panel)) then
			panel:SetVisible(false)

			if (bDelete) then
				panel:Remove()
			end
		end
	end

	self.Items = {}
end

--[[---------------------------------------------------------
   Name: ForceSelect
   Desc: Force the user to select an item by making their
   cursor only useable in the radial menu.
-----------------------------------------------------------]]
function PANEL:ForceSelect()
	-- Enable mouse input and display cursor
	self:SetMouseInputEnabled(true)
	-- gui.EnableScreenClicker(true)

	self:SetFocusTopLevel()
end
vgui.Register("DRadialMenu", PANEL, "DPanel")

concommand.Add(
	"radial_test",
	function(ply, cmd, args)
		if ValidPanel(RADIAL) then
			RADIAL:Remove()
		end

		RADIAL = vgui.Create("DRadialMenu")
		RADIAL:SetSize(ScrH(), ScrH())
		-- RADIAL:SetPaintDebug( true )
		-- RADIAL:SetRadiusPadding( 50 )
		RADIAL:SetRadiusScale(0.88)
		-- RADIAL:SetDegreeOffset( 90 )
		-- RADIAL:SetAlignMode( RADIAL_ALIGN_CENTER )
		RADIAL:Center()
		-- RADIAL:MakePopup()

		-- Add items
		for i = 1, 8 + 1 do
			local p = vgui.Create("DButton")
			p:SetSize(100, 30)
			p:SetText("Button " .. i)
			p.DoClick = function(self)
				print("Clicked " .. p:GetText())
			end

			RADIAL:AddItem(p)
			-- RADIAL:AddItem( p, math.Rand(10,35) )
		end

		-- Set Center panel
		local p = vgui.Create("DLabel")
		p:SetSize(100, 30)
		p:SetText("Center Panel")
		p:SetFont("DermaLarge")
		p:SizeToContents()
		RADIAL:SetCenterPanel(p)
	end
)

usermessage.Hook(
	"ShowScores",
	function(um)
		local display = um:ReadBool()

		GAMEMODE:DisplayScorecard(display)
	end
)

--[[usermessage.Hook( "SendHole", function(um )
	GAMEMODE.CurrentHolePos = um:ReadVector()
end )]]
