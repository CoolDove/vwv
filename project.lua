local M={}

function M._begin()
	vim.cmd('echo "Project: vwv"')
	vim.opt.expandtab = false
	vim.cmd('echo "- use tab"')
	vim.cmd('echo "- build commands in global actions"')

	local function build_release()
		vim.cmd("!make release")
	end
	local function build_debug()
		vim.cmd("!make debug")
	end

	table.insert(dove.global_actions, {'b', 'Build VWV', function()
		dove.simple.nextkeys({
			{'r', 'release', build_release},
			{'d', 'debug', build_debug},
			{'R', 'run', function()
				vim.cmd('!vwv')
			end},
		})
	end})
end

function M._end()
	dove.toggle.remove_quick_command(CMD_RELEASE)
	dove.toggle.remove_quick_command(CMD_DEBUG)
end

return M
