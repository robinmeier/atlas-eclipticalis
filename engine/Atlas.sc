Engine_Atlas : CroneEngine {

  *new { arg context, doneCallback;
    ^super.new(context, doneCallback);
  }

  alloc {
    SynthDef(\atlas_note, {
      arg out = 0, freq = 440, amp = 0.5, pan = 0.0, sustain = 1.5, release = 2.0;
      var sig, env, click;
      env   = EnvGen.kr(Env.linen(0.05, sustain, release), doneAction: Done.freeSelf);
      sig   = SinOsc.ar(freq);
      click = WhiteNoise.ar * EnvGen.kr(Env.perc(0.001, 0.04));
      sig   = (sig * 0.85 + click * 0.35) * env * amp;
      Out.ar(out, Pan2.ar(sig, pan));
    }).add;

    context.server.sync;

    this.addCommand(\note, "fffff", { |msg|
      Synth(\atlas_note, [
        \out,     context.out_b.index,
        \freq,    msg[1],
        \amp,     msg[2],
        \pan,     msg[3],
        \sustain, msg[4],
        \release, msg[5]
      ], context.xg);
    });
  }

  free {}
}
