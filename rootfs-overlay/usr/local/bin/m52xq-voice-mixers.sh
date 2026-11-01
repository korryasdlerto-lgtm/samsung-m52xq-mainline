#!/bin/sh
# M52XQ: WCD938x codec routing for a modem voice call (CS-Voice, q6voice).
# start: earpiece out + main microphone (AMIC1) in + voice mixers; stop: undo.
# Control names are the mainline wcd938x/lpass ones (UCM HiFi "Earpiece"/"Mic").
C="amixer -q -c0 cset"
# m52xq 2026-10-17: microphone gains ADC 16 / DEC 106 (the stock mixer_paths.xml values ADC 0 / DEC 84 left the far end hearing
# nothing with our chain, tested live). Order of the microphones as the stock mixer_paths.xml (call-handset-mic /
# call-speaker-mic): ADC1/ADC3 Volume 0, TX_DEC0/1 Volume 84 (0 dB), EAR_PA 6 dB, RX_RX0 Digital 84.
# The Samsung voice calibration (q6cvp cal_enable) expects these levels; the old 16/106 (+38 dB) was a
# workaround for calls without calibration. Override in /etc/m52xq-voice.conf if needed.
CALL_ADC_VOL=16
CALL_DEC_VOL=106
[ -r /etc/m52xq-voice.conf ] && . /etc/m52xq-voice.conf
case "$1" in
start)
	if [ "$2" = speaker ]; then
		# loud speaker (TFA9878 on QUINARY MI2S): the voice goes through the speaker amplifier backend
		$C "name=QUIN_MI2S_RX Voice Mixer CS-Voice" 1
	else
		$C "name=RX_MACRO RX0 MUX" AIF1_PB
		$C "name=RX INT0_1 MIX1 INP0" RX0
		$C "name=RX INT0 DEM MUX" CLSH_DSM_OUT
		$C "name=RX_COMP1 Switch" 0
		$C "name=HPHL_COMP Switch" 0
		$C "name=RX_EAR Mode Switch" 1
		$C "name=RX HPH Mode" CLS_H_LOHIFI
		$C "name=RDAC3_MUX" RX1
		$C "name=EAR_PA Volume" 0
		$C "name=RX_RX0 Digital Volume" 84
		$C "name=EAR_RDAC Switch" 1
		$C "name=HPHL Switch" 1
		$C "name=CLSH Switch" 1
		$C "name=RX_CODEC_DMA_RX_0 Voice Mixer CS-Voice" 1
	fi
	$C "name=ADC1_MIXER Switch" 1
	$C "name=ADC1 Switch" 1
	$C "name=TX0 MODE" ADC_NORMAL
	$C "name=TX DEC0 MUX" SWR_MIC
	# stock "main-sub-mic" (handset): DEC0 = AMIC1 (bottom, main), DEC1 = AMIC4 (top);
	# stock "sub-main-mic" (speaker): DEC0 = AMIC4, DEC1 = AMIC1 - the Speaker_cal tuning expects that order
	if [ "$2" = speaker ]; then
		$C "name=TX SMIC MUX0" SWR_DMIC0
	else
		$C "name=TX SMIC MUX0" ADC0
	fi
	$C "name=TX_AIF1_CAP Mixer DEC0" 1
	$C "name=DEC0 MODE" ADC_DEFAULT
	$C "name=ADC1 Volume" $CALL_ADC_VOL
	$C "name=TX_DEC0 Volume" $CALL_DEC_VOL
	# second (top) microphone AMIC4 on DEC1 = channel 2 of TX_CODEC_DMA_TX_3 (for the two-mic vocproc topology;
	# ignored by the DSP while q6cvp tx_channels=1)
	$C "name=ADC3 MUX" INP4
	$C "name=ADC3_MIXER Switch" 1
	$C "name=ADC3 Switch" 1
	$C "name=TX2 MODE" ADC_NORMAL
	$C "name=TX DEC1 MUX" SWR_MIC
	if [ "$2" = speaker ]; then
		$C "name=TX SMIC MUX1" ADC0
	else
		$C "name=TX SMIC MUX1" SWR_DMIC0
	fi
	$C "name=TX_AIF1_CAP Mixer DEC1" 1
	$C "name=DEC1 MODE" ADC_DEFAULT
	$C "name=ADC3 Volume" $CALL_ADC_VOL
	$C "name=TX_DEC1 Volume" $CALL_DEC_VOL
	$C "name=CS-Voice Capture Mixer TX_CODEC_DMA_TX_3" 1
	;;
stop)
	$C "name=RX_CODEC_DMA_RX_0 Voice Mixer CS-Voice" 0
	$C "name=QUIN_MI2S_RX Voice Mixer CS-Voice" 0
	$C "name=CS-Voice Capture Mixer TX_CODEC_DMA_TX_3" 0
	$C "name=EAR_RDAC Switch" 0
	$C "name=HPHL Switch" 0
	$C "name=CLSH Switch" 0
	$C "name=RX_EAR Mode Switch" 0
	$C "name=RX INT0_1 MIX1 INP0" ZERO
	$C "name=RX_MACRO RX0 MUX" ZERO
	# Do NOT switch the microphone path off here: PulseAudio's UCM "Mic" device keeps it enabled and never
	# re-applies it, so switching it off killed every later recording (recorder timer never started,
	# parecord got 0 bytes, 2026-10-04). Give the normal capture (recorder, video) its UCM state back:
	# same values as the Mic EnableSequence in HiFi.conf (TX_DEC0 Volume 94 there, 106 only in a call).
	$C "name=ADC1_MIXER Switch" 1
	$C "name=ADC1 Switch" 1
	$C "name=ADC1 Volume" 16
	$C "name=TX_DEC0 Volume" 94
	$C "name=TX0 MODE" ADC_NORMAL
	$C "name=TX DEC0 MUX" SWR_MIC
	$C "name=TX SMIC MUX0" ADC0
	$C "name=TX_AIF1_CAP Mixer DEC0" 1
	$C "name=DEC0 MODE" ADC_DEFAULT
	$C "name=ADC3 MUX" INP4
	$C "name=ADC3_MIXER Switch" 1
	$C "name=ADC3 Switch" 1
	$C "name=ADC3 Volume" 16
	$C "name=TX_DEC1 Volume" 94
	$C "name=TX2 MODE" ADC_NORMAL
	$C "name=TX DEC1 MUX" SWR_MIC
	$C "name=TX SMIC MUX1" SWR_DMIC0
	$C "name=TX_AIF1_CAP Mixer DEC1" 1
	$C "name=DEC1 MODE" ADC_DEFAULT
	;;
*)
	echo "usage: $0 start [speaker]|stop" >&2
	exit 1
	;;
esac
