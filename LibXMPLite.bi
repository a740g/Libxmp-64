'---------------------------------------------------------------------------------------------------------
' LibXMP Lite
' Copyright (c) 2022 Samuel Gomes
'
' Most of the stuff here is from https://github.com/libxmp/libxmp/blob/master/include/xmp.h
'---------------------------------------------------------------------------------------------------------

'---------------------------------------------------------------------------------------------------------
' HEADER FILES
'---------------------------------------------------------------------------------------------------------
'$Include:'./Common.bi'
'---------------------------------------------------------------------------------------------------------

$If LIBXMPLITE_BI = UNDEFINED Then
    $Let LIBXMPLITE_BI = TRUE
    '-----------------------------------------------------------------------------------------------------
    ' METACOMMANDS
    '-----------------------------------------------------------------------------------------------------
    ' Compiler check
    $If 32BIT Then
            $ERROR This requires the 64-bit QB64 compiler!
    $End If
    '-----------------------------------------------------------------------------------------------------

    '-----------------------------------------------------------------------------------------------------
    ' CONSTANTS
    '-----------------------------------------------------------------------------------------------------
    Const XMP_NAME_SIZE = 64 ' Size of module name and type

    Const XMP_PLAYER_INTERP = 2 ' Interpolation type
    Const XMP_PLAYER_DSP = 3 ' DSP effect flags
    Const XMP_PLAYER_VOLUME = 7 ' Player module volume

    Const XMP_MAX_CHANNELS = 64 ' Max number of channels in module

    Const XMP_INTERP_SPLINE = 2 ' Cubic spline

    Const XMP_DSP_LOWPASS = 1 ' Lowpass filter effect
    Const XMP_DSP_ALL = XMP_DSP_LOWPASS

    Const XMP_VOLUME_MAX = 100 ' Max volume in percentage

    ' Helper constants. These must be in sync with the types below
    Const XMP_CHANNEL_INFO_SIZE = 24 ' size of xmp_channel_info type
    Const XMP_CHANNEL_INFO_ARRAY_SIZE = XMP_CHANNEL_INFO_SIZE * XMP_MAX_CHANNELS

    Const XMP_SOUND_BUFFER_CHANNELS = 2 ' 2 channel (stereo)
    Const XMP_SOUND_BUFFER_SAMPLE_SIZE = 2 ' 2 bytes (16-bits signed integer)
    Const XMP_SOUND_BUFFER_FRAME_SIZE = XMP_SOUND_BUFFER_SAMPLE_SIZE * XMP_SOUND_BUFFER_CHANNELS
    Const XMP_SOUND_TIME_MIN = 0.2 ' We will check that we have this amount of time left in the QB64 sound pipe
    '-----------------------------------------------------------------------------------------------------

    '-----------------------------------------------------------------------------------------------------
    ' USER DEFINED TYPES
    '-----------------------------------------------------------------------------------------------------
    ' Info type used with xmp_test_module()
    Type xmp_test_info
        mod_name As String * Xmp_name_size ' Module title
        mod_type As String * Xmp_name_size ' Module format
    End Type

    Type xmp_event
        note As Unsigned Byte ' Note number (0 means no note)
        ins As Unsigned Byte ' Patch number
        vol As Unsigned Byte ' Volume (0 to basevol)
        fxt As Unsigned Byte ' Effect type
        fxp As Unsigned Byte ' Effect parameter
        f2t As Unsigned Byte ' Secondary effect type
        f2p As Unsigned Byte ' Secondary effect parameter
        flag As Unsigned Byte ' Internal (reserved) flags
    End Type

    Type xmp_channel_info
        period As Unsigned Long ' Sample period (* 4096)
        position As Unsigned Long ' Sample position
        pitchbend As Integer ' Linear bend from base note
        note As Unsigned Byte ' Current base note number
        instrument As Unsigned Byte ' Current instrument number
        sample As Unsigned Byte ' Current sample number
        volume As Unsigned Byte ' Current volume
        pan As Unsigned Byte ' Current stereo pan
        reserved As Unsigned Byte ' Reserved
        event As xmp_event ' Current track event
    End Type

    ' Info type used with xmp_get_frame_info()
    Type xmp_frame_info
        position As Long ' Current position
        pattern As Long ' Current pattern
        row As Long ' Current row in pattern
        num_rows As Long ' Number of rows in current pattern
        frame As Long ' Current frame
        speed As Long ' Current replay speed
        bpm As Long ' Current bpm
        time As Long ' Current module time in ms
        total_time As Long ' Estimated replay time in ms*/
        frame_time As Long ' Frame replay time in us
        buffer As Offset ' Pointer to sound buffer
        buffer_size As Long ' Used buffer size
        total_size As Long ' Total buffer size
        volume As Long ' Current master volume
        loop_count As Long ' Loop counter
        virt_channels As Long ' Number of virtual channels
        virt_used As Long ' Used virtual channels
        sequence As Long ' Current sequence
        channel_info As String * Xmp_channel_info_array_size ' Current channel information
    End Type

    ' QB64 specific stuff
    Type XMPPlayerType
        context As Offset ' This is a libxmp context
        isPlaying As Byte ' Set to true if tune is playing
        isPaused As Byte ' Set to true if tune is paused
        isLooping As Byte ' Set to true if tune is looping
        frameInfo As xmp_frame_info ' Current frame info. This is used to check if we are looping or playback is done
        testInfo As xmp_test_info ' This will have the MOD name and type
        errorCode As Long ' This hold the error code from a previous XMP function
        soundBuffer As MEM ' This is the buffer that holds the rendered samples from libxmp
        soundBufferSize As Unsigned Long ' Size of the render buffer
        soundHandle As Long ' The sound pipe that we wll use to play the rendered samples
    End Type
    '-----------------------------------------------------------------------------------------------------

    '-----------------------------------------------------------------------------------------------------
    ' EXTERNAL LIBRARIES
    '-----------------------------------------------------------------------------------------------------
    $If WINDOWS Then
            Declare Static Library "./libxmp_win"
    $ElseIf LINUX Then
        Declare Static Library "./xmp_lnx" ' QB64 removes the 'lib' prefix on Linux
        $ElseIf MACOSX Then
            $ERROR macOS is not supported yet!
            Declare Static Library "./xmp_osx"
        $Else
            $ERROR Unknown platform!
            Declare Static Library "./xmp"
        $End If
        Function xmp_create_context%&
        Sub xmp_free_context (ByVal context As Offset)
        Function xmp_test_module& (path As String, test_info As xmp_test_info)
        Function xmp_load_module& (ByVal context As Offset, path As String)
        Sub xmp_release_module (ByVal context As Offset)
        Function xmp_start_player& (ByVal context As Offset, Byval rate As Long, Byval format As Long)
        Sub xmp_end_player (ByVal context As Offset)
        Function xmp_play_buffer& (ByVal context As Offset, Byval buffer As Offset, Byval size As Long, Byval loops As Long)
        Sub xmp_get_frame_info (ByVal context As Offset, frame_info As xmp_frame_info)
        Function xmp_get_player& (ByVal context As Offset, Byval param As Long)
        Function xmp_set_player& (ByVal context As Offset, Byval param As Long, Byval value As Long)
    End Declare
    '-----------------------------------------------------------------------------------------------------

    '-----------------------------------------------------------------------------------------------------
    ' GLOBAL VARIABLES
    '-----------------------------------------------------------------------------------------------------
    Dim Shared XMPPlayer As XMPPlayerType
    '-----------------------------------------------------------------------------------------------------
$End If
'---------------------------------------------------------------------------------------------------------

