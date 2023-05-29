'-----------------------------------------------------------------------------------------------------------------------
' Libxmp bindings for QB64-PE (minimalistic)
' Copyright (c) 2023 Samuel Gomes
'
' This mostly has the glue code that make working with Libxmp and QB64-PE easy
'-----------------------------------------------------------------------------------------------------------------------

'-----------------------------------------------------------------------------------------------------------------------
' HEADER FILES
'-----------------------------------------------------------------------------------------------------------------------
'$INCLUDE:'Libxmp64.bi'
'-----------------------------------------------------------------------------------------------------------------------

$If LIBXMP64_BAS = UNDEFINED Then
    $Let LIBXMP64_BAS = TRUE
    '-------------------------------------------------------------------------------------------------------------------
    ' FUNCTIONS & SUBROUTINES
    '-------------------------------------------------------------------------------------------------------------------
    ' Rounds a number down to a power of 2 (this time the non-noobie way :)
    Function __XMP_RoundDownToPowerOf2~& (i As _Unsigned Long)
        Dim j As _Unsigned Long
        j = i
        j = j Or _ShR(j, 1)
        j = j Or _ShR(j, 2)
        j = j Or _ShR(j, 4)
        j = j Or _ShR(j, 8)
        j = j Or _ShR(j, 16)
        __XMP_RoundDownToPowerOf2 = j - _ShR(j, 1)
    End Function


    ' This an internal fuction and should be called right after the module is loaded
    ' These are things that are common after loading a module
    Function __XMP_DoPostInit%%
        Shared __XMPPlayer As __XMPPlayerType

        ' Exit if module loading failed
        If __XMPPlayer.errorCode <> 0 Then
            ' Free the context
            xmp_free_context __XMPPlayer.context
            __XMPPlayer.context = 0
            Exit Function
        End If

        ' Initialize the player
        __XMPPlayer.errorCode = xmp_start_player(__XMPPlayer.context, _SndRate, 0)

        ' Exit if starting player failed
        If __XMPPlayer.errorCode <> 0 Then
            xmp_release_module __XMPPlayer.context
            xmp_free_context __XMPPlayer.context
            __XMPPlayer.context = 0
            Exit Function
        End If

        ' Allocate the mixer buffer
        __XMPPlayer.soundBufferFrames = __XMP_RoundDownToPowerOf2(_SndRate * 0.04) ' 40 ms buffer round down to power of 2
        __XMPPlayer.soundBufferBytes = __XMPPlayer.soundBufferFrames * XMP_SOUND_BUFFER_FRAME_SIZE ' power of 2 above is required by most FFT functions
        __XMPPlayer.soundBuffer = _MemNew(__XMPPlayer.soundBufferBytes)

        ' Exit if memory was not allocated
        If __XMPPlayer.soundBuffer.SIZE = 0 Then
            xmp_end_player __XMPPlayer.context
            xmp_release_module __XMPPlayer.context
            xmp_free_context __XMPPlayer.context
            __XMPPlayer.context = 0
            Exit Function
        End If

        ' Set some player properties
        ' These makes the sound quality much better when devices have sample rates other than 44100
        __XMPPlayer.errorCode = xmp_set_player(__XMPPlayer.context, XMP_PLAYER_INTERP, XMP_INTERP_SPLINE)
        __XMPPlayer.errorCode = xmp_set_player(__XMPPlayer.context, XMP_PLAYER_DSP, XMP_DSP_ALL)

        ' Allocate a sound pipe
        __XMPPlayer.soundHandle = _SndOpenRaw

        ' Exit if failed to allocate sound handle
        If __XMPPlayer.soundHandle < 1 Then
            _MemFree __XMPPlayer.soundBuffer
            xmp_end_player __XMPPlayer.context
            xmp_release_module __XMPPlayer.context
            xmp_free_context __XMPPlayer.context
            __XMPPlayer.context = 0
            Exit Function
        End If

        ' Get the frame information
        xmp_get_frame_info __XMPPlayer.context, __XMPPlayer.frameInfo

        ' Set default player state
        __XMPPlayer.isPlaying = 0
        __XMPPlayer.isLooping = 0
        __XMPPlayer.isPaused = __XMPPlayer.context <> 0 ' true

        __XMP_DoPostInit = __XMPPlayer.context <> 0 ' true
    End Function


    ' Loads the MOD tune from a file and prepares all required gobals
    Function XMP_LoadTuneFromFile%% (fileName As String)
        Shared __XMPPlayer As __XMPPlayerType

        ' Check if the file exists
        If Not _FileExists(fileName) Then Exit Function

        ' If a song is already loaded then unload and free resources
        If __XMPPlayer.context <> 0 Then XMP_Stop

        ' Check if the file is a valid module music
        __XMPPlayer.errorCode = xmp_test_module(fileName + Chr$(0), __XMPPlayer.testInfo)
        If __XMPPlayer.errorCode <> 0 Then Exit Function

        ' Initialize the player
        __XMPPlayer.context = xmp_create_context

        ' Exit if context creation failed
        If __XMPPlayer.context = 0 Then Exit Function

        ' Load the module file
        __XMPPlayer.errorCode = xmp_load_module(__XMPPlayer.context, fileName + Chr$(0))

        XMP_LoadTuneFromFile = __XMP_DoPostInit
    End Function


    ' Loads the MOD tune from a memory and prepares all required gobals
    Function XMP_LoadTuneFromMemory%% (buffer As String)
        Shared __XMPPlayer As __XMPPlayerType
        ' Check if the buffer is empty
        If Len(buffer) = 0 Then Exit Function

        ' If a song is already loaded then unload and free resources
        If __XMPPlayer.context <> 0 Then XMP_Stop

        ' Check if the file is a valid module music
        __XMPPlayer.errorCode = xmp_test_module_from_memory(buffer, Len(buffer), __XMPPlayer.testInfo)
        If __XMPPlayer.errorCode <> 0 Then Exit Function

        ' Initialize the player
        __XMPPlayer.context = xmp_create_context

        ' Exit if context creation failed
        If __XMPPlayer.context = 0 Then Exit Function

        ' Load the module file
        __XMPPlayer.errorCode = xmp_load_module_from_memory(__XMPPlayer.context, buffer, Len(buffer))

        XMP_LoadTuneFromMemory = __XMP_DoPostInit
    End Function


    ' Kickstarts playback
    Sub XMP_Play
        Shared __XMPPlayer As __XMPPlayerType

        If __XMPPlayer.context <> 0 Then
            __XMPPlayer.isPaused = 0 ' false
            __XMPPlayer.isPlaying = (__XMPPlayer.context <> 0) ' true
        End If
    End Sub


    ' Stops the player and frees all allocated resources
    Sub XMP_Stop
        Shared __XMPPlayer As __XMPPlayerType

        ' Free the player and loaded module
        If __XMPPlayer.context <> 0 Then
            ' Set default player state
            __XMPPlayer.isPlaying = 0
            __XMPPlayer.isLooping = 0
            __XMPPlayer.isPaused = __XMPPlayer.context <> 0 ' true

            ' Free the sound pipe
            _SndRawDone __XMPPlayer.soundHandle ' Sumbit whatever is remaining in the raw buffer for playback
            _SndClose __XMPPlayer.soundHandle ' Close QB64 sound pipe

            ' Free the mixer buffer
            _MemFree __XMPPlayer.soundBuffer

            ' Cleanup XMP
            xmp_end_player __XMPPlayer.context
            xmp_release_module __XMPPlayer.context
            xmp_free_context __XMPPlayer.context
            __XMPPlayer.context = 0
        End If
    End Sub


    ' Restarts playback
    Sub XMP_Replay
        Shared __XMPPlayer As __XMPPlayerType

        If __XMPPlayer.context <> 0 And __XMPPlayer.isPlaying And Not __XMPPlayer.isPaused Then
            xmp_restart_module __XMPPlayer.context
        End If
    End Sub


    ' Jumps to the next position
    Sub XMP_GoToNextPosition
        Shared __XMPPlayer As __XMPPlayerType

        If __XMPPlayer.context <> 0 And __XMPPlayer.isPlaying And Not __XMPPlayer.isPaused Then
            __XMPPlayer.errorCode = xmp_next_position&(__XMPPlayer.context)
        End If
    End Sub


    ' Jumps to the previous position
    Sub XMP_GoToPreviousPosition
        Shared __XMPPlayer As __XMPPlayerType

        If __XMPPlayer.context <> 0 And __XMPPlayer.isPlaying And Not __XMPPlayer.isPaused Then
            __XMPPlayer.errorCode = xmp_prev_position&(__XMPPlayer.context)
        End If
    End Sub


    ' Just to a specific position
    Sub XMP_SetPosition (position As Long)
        Shared __XMPPlayer As __XMPPlayerType

        If __XMPPlayer.context <> 0 And __XMPPlayer.isPlaying And Not __XMPPlayer.isPaused Then
            __XMPPlayer.errorCode = xmp_set_position&(__XMPPlayer.context, position)
        End If
    End Sub


    ' Just to a specific time
    Sub XMP_SeekToTime (timeMs As Long)
        Shared __XMPPlayer As __XMPPlayerType

        If __XMPPlayer.context <> 0 And __XMPPlayer.isPlaying And Not __XMPPlayer.isPaused Then
            __XMPPlayer.errorCode = xmp_seek_time&(__XMPPlayer.context, timeMs)
        End If
    End Sub


    ' This handles playback and keeping track of the render buffer
    ' You can call this as frequenctly as you want. The routine will simply exit if nothing is to be done
    Sub XMP_Update (bufferTimeSecs As Single)
        Shared __XMPPlayer As __XMPPlayerType

        ' If song is done, paused or we already have enough samples to play then exit
        If __XMPPlayer.context = 0 Or Not __XMPPlayer.isPlaying Or __XMPPlayer.isPaused Or _SndRawLen(__XMPPlayer.soundHandle) > bufferTimeSecs Then Exit Sub

        ' Clear the render buffer
        _MemFill __XMPPlayer.soundBuffer, __XMPPlayer.soundBuffer.OFFSET, __XMPPlayer.soundBufferBytes, 0 As _BYTE

        ' Render some samples to the buffer
        __XMPPlayer.errorCode = xmp_play_buffer(__XMPPlayer.context, __XMPPlayer.soundBuffer.OFFSET, __XMPPlayer.soundBufferBytes, 0)

        ' Get the frame information
        xmp_get_frame_info __XMPPlayer.context, __XMPPlayer.frameInfo

        ' Set playing flag to false if we are not looping and loop count > 0
        If __XMPPlayer.isLooping Then
            __XMPPlayer.isPlaying = __XMPPlayer.isLooping
        Else
            __XMPPlayer.isPlaying = (__XMPPlayer.frameInfo.loop_count < 1)
            ' Exit before any samples are queued
            If Not __XMPPlayer.isPlaying Then Exit Sub
        End If

        ' Push the samples to the sound pipe
        Dim i As _Unsigned Long
        For i = 0 To __XMPPlayer.soundBufferBytes - XMP_SOUND_BUFFER_SAMPLE_SIZE Step XMP_SOUND_BUFFER_FRAME_SIZE
            _SndRaw _MemGet(__XMPPlayer.soundBuffer, __XMPPlayer.soundBuffer.OFFSET + i, Integer) / 32768!, _MemGet(__XMPPlayer.soundBuffer, __XMPPlayer.soundBuffer.OFFSET + i + XMP_SOUND_BUFFER_SAMPLE_SIZE, Integer) / 32768!, __XMPPlayer.soundHandle
        Next
    End Sub


    ' Sets the master volume (0 - 100)
    Sub XMP_SetVolume (volume As Long)
        Shared __XMPPlayer As __XMPPlayerType

        If __XMPPlayer.context <> 0 And __XMPPlayer.isPlaying Then
            If volume < 0 Then
                __XMPPlayer.errorCode = xmp_set_player(__XMPPlayer.context, XMP_PLAYER_VOLUME, 0)
            ElseIf volume > 100 Then
                __XMPPlayer.errorCode = xmp_set_player(__XMPPlayer.context, XMP_PLAYER_VOLUME, 100)
            Else
                __XMPPlayer.errorCode = xmp_set_player(__XMPPlayer.context, XMP_PLAYER_VOLUME, volume)
            End If
        End If
    End Sub


    ' Gets the master volume
    Function XMP_GetVolume&
        Shared __XMPPlayer As __XMPPlayerType

        If __XMPPlayer.context <> 0 And __XMPPlayer.isPlaying Then
            XMP_GetVolume = xmp_get_player(__XMPPlayer.context, XMP_PLAYER_VOLUME)
        End If
    End Function


    ' Pauses / unpauses playback
    Sub XMP_Pause (state As _Byte)
        Shared __XMPPlayer As __XMPPlayerType

        If __XMPPlayer.context <> 0 Then
            __XMPPlayer.isPaused = state <> 0
        End If
    End Sub


    ' Returns true if player is paused
    Function XMP_IsPaused%%
        Shared __XMPPlayer As __XMPPlayerType

        If __XMPPlayer.context <> 0 Then
            XMP_IsPaused = __XMPPlayer.isPaused
        End If
    End Function


    ' Enables / disables playback looping
    Sub XMP_Loop (state As _Byte)
        Shared __XMPPlayer As __XMPPlayerType

        If __XMPPlayer.context <> 0 Then
            __XMPPlayer.isLooping = state <> 0
        End If
    End Sub


    ' Returns true if playback is looping
    Function XMP_IsLooping%%
        Shared __XMPPlayer As __XMPPlayerType

        If __XMPPlayer.context <> 0 Then
            XMP_IsLooping = __XMPPlayer.isLooping
        End If
    End Function


    ' Returns true if music is playing
    Function XMP_IsPlaying%%
        Shared __XMPPlayer As __XMPPlayerType

        If __XMPPlayer.context <> 0 Then
            XMP_IsPlaying = __XMPPlayer.isPlaying
        End If
    End Function
    '-------------------------------------------------------------------------------------------------------------------
$End If
'-----------------------------------------------------------------------------------------------------------------------
