local M = {}

local config = require("djortcuts.config")

local LogEntry = {}
LogEntry.__index = LogEntry

function LogEntry:new(data)
	local instance = {
		id = data.id,
		timestamp = data.timestamp,
		command = data.command,
		output = data.output or {},
		exit_code = data.exit_code,
		duration_ms = data.duration_ms,
	}
	setmetatable(instance, LogEntry)
	return instance
end

local logs = {}
local next_id = 1

function M.add(entry)
	local log_entry = LogEntry:new({
		id = next_id,
		timestamp = os.date("%Y-%m-%d %H:%M:%S"),
		command = entry.command,
		output = entry.output or {},
		exit_code = entry.exit_code,
		duration_ms = entry.duration_ms,
	})

	table.insert(logs, log_entry)
	next_id = next_id + 1

	M.prune()

	return log_entry.id
end

function M.list()
	local result = {}
	for _, log in ipairs(logs) do
		table.insert(result, {
			id = log.id,
			timestamp = log.timestamp,
			command = log.command,
			exit_code = log.exit_code,
		})
	end
	return result
end

function M.get(id)
	for _, log in ipairs(logs) do
		if log.id == id then
			return log
		end
	end
	return nil
end

function M.prune()
	local max_entries = config.config.max_log_entries or 50
	while #logs > max_entries do
		table.remove(logs, 1)
	end
end

function M.clear()
	logs = {}
	next_id = 1
end

return M
