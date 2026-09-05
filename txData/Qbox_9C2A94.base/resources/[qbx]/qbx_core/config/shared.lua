return {
    serverName = 'NoPixel India',
    defaultSpawn = vec4(-540.58, -212.02, 37.65, 208.88),
    notifyPosition = 'top-right',
    ---@type { name: string, amount: integer, metadata: fun(source: number): table }[]
    starterItems = {
        { name = 'phone', amount = 1 },
        { name = 'id_card', amount = 1, metadata = function(source)
                assert(GetResourceState('qbx_idcard') == 'started', 'qbx_idcard resource not found. Required to give an id_card as a starting item')
                return exports.qbx_idcard:GetMetaLicense(source, {'id_card'})
            end
        },
        { name = 'driver_license', amount = 1, metadata = function(source)
                assert(GetResourceState('qbx_idcard') == 'started', 'qbx_idcard resource not found. Required to give a driver_license as a starting item')
                return exports.qbx_idcard:GetMetaLicense(source, {'driver_license'})
            end
        },
    }
}
