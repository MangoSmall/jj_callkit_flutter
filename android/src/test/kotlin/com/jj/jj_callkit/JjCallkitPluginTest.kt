package com.jj.jj_callkit

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test

internal class JjCallkitPluginTest {
    @Test
    fun onMethodCall_unknownMethod_isNotImplemented() {
        val plugin = JjCallkitPlugin()
        val call = MethodCall("notARealMethod", null)
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(call, mockResult)
        Mockito.verify(mockResult).notImplemented()
    }
}
