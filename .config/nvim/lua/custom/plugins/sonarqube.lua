return {
	"iamkarasik/sonarqube.nvim",
	lazy = false,
	config = function()
		local extension_path = vim.fn.stdpath("data") .. "/mason/packages/sonarlint-language-server/extension"

		-- Nvim 0.12 deprecates client.notify (dot-call style).
		-- Patch plugin callback to use method style client:notify.
		local ok_server, server = pcall(require, "sonarqube.lsp.server")
		if ok_server then
			server.did_change_configuration = function(client)
				local sonarqube = client or vim.lsp.get_clients({ name = "sonarqube" })[1]
				if not sonarqube then
					return
				end
				sonarqube:notify("workspace/didChangeConfiguration", {
					settings = server.settings,
				})
			end
		end

		require("sonarqube").setup({
			lsp = {
				cmd = {
					vim.fn.exepath("java"),
					"-jar",
					extension_path .. "/server/sonarlint-ls.jar",
					"-stdio",
					"-analyzers",
					extension_path .. "/analyzers/sonargo.jar",
					extension_path .. "/analyzers/sonarhtml.jar",
					extension_path .. "/analyzers/sonariac.jar",
					extension_path .. "/analyzers/sonarjava.jar",
					extension_path .. "/analyzers/sonarjavasymbolicexecution.jar",
					extension_path .. "/analyzers/sonarjs.jar",
					extension_path .. "/analyzers/sonarphp.jar",
					extension_path .. "/analyzers/sonarpython.jar",
					extension_path .. "/analyzers/sonartext.jar",
					extension_path .. "/analyzers/sonarxml.jar",
				},
			},
		})
	end,
}
