"""Tester for Python-skriptene. Kjører uten enhet, mot en oppdiktet config i fixtures/.

  python3 -m unittest discover -s tests -v
"""
import binascii
import hashlib
import importlib.util
import io
import json
import os
import struct
import subprocess
import sys
import tempfile
import unittest
import zipfile

ROT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKRIPT = os.path.join(ROT, "scripts")
FIXTURE = os.path.join(ROT, "tests", "fixtures", "zcfg_config.json")
sys.path.insert(0, os.path.join(SKRIPT, "lib"))
import zcfg  # noqa: E402


def run(*args):
    return subprocess.run([sys.executable, *args], capture_output=True, text=True)


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def load_module(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class TmpDir(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = self._tmp.name

    def tearDown(self):
        self._tmp.cleanup()

    def p(self, name):
        return os.path.join(self.tmp, name)


class LokalAdministrasjon(TmpDir):
    SKRIPT = os.path.join(SKRIPT, "61-zyxel-lag-config-lokal-administrasjon.py")

    def test_endrer_akkurat_de_sju_verdiene(self):
        r = run(self.SKRIPT, FIXTURE, self.p("ny.json"))
        self.assertEqual(r.returncode, 0, r.stderr)
        before, after = zcfg.load(FIXTURE), zcfg.load(self.p("ny.json"))
        diff = {k: n for k, _, n in zcfg.changes(before, after)}
        self.assertEqual(diff, {
            "X_ZYXEL_EXT.BootFromFactoryDefault": False,
            "DHCPv4.Server.Enable": True,
            "X_ZYXEL_RemoteManagement.Service[1].Mode": "LAN_ONLY",
            "X_ZYXEL_RemoteManagement.Service[4].Mode": "LAN_ONLY",
            "X_ZYXEL_RemoteManagement.Service[4].DisableSshPasswordLogin": False,
            "X_ZYXEL_LoginCfg.LogGp[0].Account[1].Enabled": True,
            "X_ZYXEL_LoginCfg.LogGp[1].Account[0].Enabled": True,
        })

    def test_beholder_formatering(self):
        run(self.SKRIPT, FIXTURE, self.p("ny.json"))
        orig = read(FIXTURE).splitlines()
        new = read(self.p("ny.json")).splitlines()
        self.assertEqual(len(orig), len(new))
        self.assertEqual(sum(a != b for a, b in zip(orig, new)), 7)

    def test_kan_kjoeres_to_ganger(self):
        run(self.SKRIPT, FIXTURE, self.p("en.json"))
        r = run(self.SKRIPT, self.p("en.json"), self.p("to.json"))
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("Ingen endringer", r.stdout)
        self.assertEqual(read(self.p("en.json")), read(self.p("to.json")))

    def test_finner_tjenester_paa_navn(self):
        d = zcfg.load(FIXTURE)
        svc = d["X_ZYXEL_RemoteManagement"]["Service"]
        svc.append(svc.pop(1))   # HTTPS sist
        with open(self.p("omstokket.json"), "w") as f:
            f.write(json.dumps(d, indent=2, separators=(",", ":")))
        r = run(self.SKRIPT, self.p("omstokket.json"), self.p("ny.json"))
        self.assertEqual(r.returncode, 0, r.stderr)
        after = zcfg.load(self.p("ny.json"))
        modes = {s["Name"]: s["Mode"] for s in after["X_ZYXEL_RemoteManagement"]["Service"]}
        self.assertEqual(modes["HTTPS"], "LAN_ONLY")
        self.assertEqual(modes["SSH"], "LAN_ONLY")
        self.assertEqual(modes["HTTP"], "WAN_ONLY")

    def test_manglende_konto_gir_feil_og_ingen_fil(self):
        d = zcfg.load(FIXTURE)
        d["X_ZYXEL_LoginCfg"]["LogGp"][1]["Account"] = []
        with open(self.p("uten-admin.json"), "w") as f:
            json.dump(d, f)
        r = run(self.SKRIPT, self.p("uten-admin.json"), self.p("ny.json"))
        self.assertNotEqual(r.returncode, 0)
        self.assertFalse(os.path.exists(self.p("ny.json")))


class ApnOgFjernstyring(TmpDir):
    SKRIPT = os.path.join(SKRIPT, "lib", "lag-apn-og-fjernstyring-config.py")

    def test_setter_apn_og_slaar_av_fjernstyring(self):
        r = run(self.SKRIPT, FIXTURE, self.p("ny.json"), "--apn", "telia")
        self.assertEqual(r.returncode, 0, r.stderr)
        d = zcfg.load(self.p("ny.json"))
        aps = d["Cellular"]["AccessPoint"]
        self.assertEqual([a["APN"] for a in aps[:2]], ["telia", "telia"])
        self.assertEqual(aps[2]["APN"], "")
        self.assertFalse(d["ManagementServer"]["EnableCWMP"])
        self.assertEqual(d["ManagementServer"]["URL"], "")
        self.assertFalse(d["ManagementServer"]["PeriodicInformEnable"])
        self.assertFalse(any(c["Enable"] for c in d["LocalAgent"]["Controller"]))
        self.assertFalse(any(m["Enable"] for m in d["LocalAgent"]["MTP"]))
        self.assertFalse(any(c["Enable"] for c in d["MQTT"]["Client"]))
        self.assertFalse(any(s["Enable"] for s in d["X_ZYXEL_RemoteManagement_IP_PassThrough"]["Service"]))
        keys = [a["SshKeyBaseAuthPublicKey"] for g in d["X_ZYXEL_LoginCfg"]["LogGp"] for a in g["Account"]]
        self.assertEqual(set(keys), {""})

    def test_egne_profiler(self):
        run(self.SKRIPT, FIXTURE, self.p("ny.json"), "--apn", "x", "--profiler", "1")
        aps = zcfg.load(self.p("ny.json"))["Cellular"]["AccessPoint"]
        self.assertEqual([a["APN"] for a in aps[:2]], ["operator.mgmt", "x"])

    def test_ukjent_profil_gir_feil(self):
        r = run(self.SKRIPT, FIXTURE, self.p("ny.json"), "--apn", "x", "--profiler", "0,9")
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("profil 9", r.stderr)
        self.assertFalse(os.path.exists(self.p("ny.json")))

    def test_apn_er_paakrevd(self):
        self.assertNotEqual(run(self.SKRIPT, FIXTURE, self.p("ny.json")).returncode, 0)


class ConfigVerdi(TmpDir):
    def test_local_yml_legges_oppaa(self):
        cv = load_module(os.path.join(SKRIPT, "lib", "config-verdi.py"), "config_verdi")
        with open(self.p("zyxel_nr7302.yml"), "w") as f:
            f.write("mobil:\n  apn: null\n  apn_profiler: [0, 1]\npc:\n  enhet_adresse: 192.168.2.1\n")
        with open(self.p("zyxel_nr7302.local.yml"), "w") as f:
            f.write("mobil:\n  apn: ice.net\n")
        cfg = cv.load(self.tmp)
        self.assertEqual(cv.fmt(cv.get(cfg, "mobil.apn")), "ice.net")
        self.assertEqual(cv.fmt(cv.get(cfg, "mobil.apn_profiler")), "0,1")
        self.assertEqual(cv.fmt(cv.get(cfg, "pc.enhet_adresse")), "192.168.2.1")
        self.assertEqual(cv.fmt(cv.get(cfg, "finnes.ikke")), "")

    def test_repoets_yml_kan_leses(self):
        r = run(os.path.join(SKRIPT, "lib", "config-verdi.py"), "mobil.apn_profiler")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout.strip(), "0,1")


def hdr1_image(payload=b"\xAB" * 4096, model=0x7302):
    hdr = bytearray(0x17C)
    struct.pack_into("<I", hdr, 0, 0x31524448)
    hdr[0x11C:0x120] = bytes([(model >> 12) & 0xF, (model >> 8) & 0xF, (model >> 4) & 0xF, model & 0xF])
    struct.pack_into("<I", hdr, 0x0C, binascii.crc32(payload) & 0xFFFFFFFF)
    struct.pack_into("<I", hdr, 0x174, binascii.crc32(bytes(hdr)) & 0xFFFFFFFF)
    return bytes(hdr) + payload


class Firmwarefil(TmpDir):
    SKRIPT = os.path.join(SKRIPT, "22-pc-sjekk-firmwarefil.py")

    def lag(self, name, feil_md5=False, model=0x7302):
        files = {n: os.urandom(1024) for n in ("oemapp.ubi", "sdxlemur-sysfs.ubi", "NON-HLOS.ubi", "multifota.bin")}
        files["sdxlemur-boot.img"] = hdr1_image(model=model)
        parts = "".join(
            f"<partition><image>{n}</image><newmd5>{'0' * 32 if feil_md5 else hashlib.md5(b).hexdigest()}</newmd5></partition>"
            for n, b in files.items())
        files["fotaconfig.xml"] = f"<fota><version>TEST</version>{parts}</fota>".encode()
        buf = io.BytesIO()
        with zipfile.ZipFile(buf, "w") as z:
            for n, b in files.items():
                z.writestr(n, b)
        path = self.p(name)
        with open(path, "wb") as f:
            f.write(buf.getvalue())
        return path

    def test_gyldig_fil(self):
        r = run(self.SKRIPT, self.lag("ok.bin"))
        self.assertEqual(r.returncode, 0, r.stdout)
        self.assertIn("RESULTAT: OK", r.stdout)

    def test_feil_md5(self):
        r = run(self.SKRIPT, self.lag("md5.bin", feil_md5=True))
        self.assertNotEqual(r.returncode, 0)

    def test_feil_modell(self):
        r = run(self.SKRIPT, self.lag("modell.bin", model=0x5103))
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("modell-ID", r.stdout)

    def test_ikke_zip(self):
        with open(self.p("tull.bin"), "wb") as f:
            f.write(b"<html>blokkert</html>")
        self.assertNotEqual(run(self.SKRIPT, self.p("tull.bin")).returncode, 0)


class VisConfig(unittest.TestCase):
    def test_kjoerer_paa_fixture(self):
        r = run(os.path.join(SKRIPT, "41-zyxel-vis-config.py"), FIXTURE)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("BootFromFactoryDefault = true", r.stdout)
        self.assertIn("kryptert", r.stdout)


class AdbSkrivConfig(TmpDir):
    """lib/felles.sh: adb_skriv_config og adb_omstart_og_vent mot en falsk adb."""

    def setUp(self):
        super().setUp()
        self.root = self.p("enhet")
        os.makedirs(os.path.join(self.root, "xdata"))
        os.makedirs(os.path.join(self.root, "tmp"))
        self.live = os.path.join(self.root, "xdata", "zcfg_config.json")
        with open(self.live, "w") as f:
            f.write('{"gammel":true}')
        bindir = self.p("bin")
        os.makedirs(bindir)
        os.symlink(os.path.join(ROT, "tests", "fake_adb.py"), os.path.join(bindir, "adb"))
        self.env = dict(os.environ, FAKE_ADB_ROOT=self.root, PATH=bindir + os.pathsep + os.environ["PATH"])

    def bash(self, script, **env):
        felles = os.path.join(SKRIPT, "lib", "felles.sh")
        return subprocess.run(["bash", "-c", f'set -euo pipefail; . "{felles}"; {script}'],
                              capture_output=True, text=True, env=dict(self.env, **env))

    def test_skriver_og_rydder(self):
        r = self.bash(f'adb_skriv_config "{FIXTURE}"')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(read(self.live), read(FIXTURE))
        self.assertEqual(sorted(os.listdir(os.path.join(self.root, "xdata"))), ["zcfg_config.json"])
        self.assertEqual(os.listdir(os.path.join(self.root, "tmp")), [])

    def test_md5_avvik_lar_config_vaere(self):
        r = self.bash(f'adb_skriv_config "{FIXTURE}"', FAKE_ADB_KORRUPT="1")
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("IKKE endret", r.stderr)
        self.assertEqual(read(self.live), '{"gammel":true}')
        self.assertEqual(sorted(os.listdir(os.path.join(self.root, "xdata"))), ["zcfg_config.json"])

    def test_ugyldig_json_skrives_ikke(self):
        with open(self.p("tull.json"), "w") as f:
            f.write("{ikke json")
        r = self.bash(f'adb_skriv_config "{self.p("tull.json")}"')
        self.assertNotEqual(r.returncode, 0)
        self.assertEqual(read(self.live), '{"gammel":true}')

    def test_omstart_og_vent(self):
        r = self.bash("adb_omstart_og_vent 30")
        self.assertEqual(r.returncode, 0, r.stderr)


if __name__ == "__main__":
    unittest.main()
