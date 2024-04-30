local M={}

local CMD_RELEASE = "vwv: build release"
local CMD_DEBUG = "vwv: build debug"

function M._begin()
	print("Project: vwv")
	vim.opt.expandtab = false
	print("- use tab")
	print("- register quick commands: ")
	print("	"..CMD_RELEASE)
	print("	"..CMD_DEBUG)
	local build_release = function()
		vim.cmd("!make release")
	end
	local build_debug = function()
		vim.cmd("!make debug")
	end
	dove.toggle.register_quick_command(CMD_RELEASE, build_release)
	dove.toggle.register_quick_command(CMD_DEBUG, build_debug)

	print("- keymaps: \n\t<C-F5> to build release, <S-F5> to build debug.")
	vim.keymap.set('n', '<C-F5>', build_release, {})
	vim.keymap.set('n', '<S-F5>', build_debug, {})
end

function M._end()
	dove.toggle.remove_quick_command(CMD_RELEASE)
	dove.toggle.remove_quick_command(CMD_DEBUG)
end

return M
