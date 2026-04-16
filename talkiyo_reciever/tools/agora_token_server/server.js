const fs = require('fs');
const path = require('path');

const cors = require('cors');
const express = require('express');
const {RtcRole, RtcTokenBuilder} = require('agora-access-token');

const configPath = path.join(__dirname, 'config.local.json');

function loadFileConfig() {
  if (!fs.existsSync(configPath)) {
    return {};
  }

  try {
    return JSON.parse(fs.readFileSync(configPath, 'utf8'));
  } catch (error) {
    throw new Error(`Invalid token server config at ${configPath}: ${error.message}`);
  }
}

function resolveConfig() {
  const fileConfig = loadFileConfig();
  const activeCertificate =
    process.env.AGORA_ACTIVE_CERTIFICATE ||
    fileConfig.activeCertificate ||
    'primary';

  const primaryCertificate =
    process.env.AGORA_APP_CERTIFICATE_PRIMARY ||
    fileConfig.primaryCertificate ||
    '';
  const secondaryCertificate =
    process.env.AGORA_APP_CERTIFICATE_SECONDARY ||
    fileConfig.secondaryCertificate ||
    '';

  return {
    appId: process.env.AGORA_APP_ID || fileConfig.appId || '',
    activeCertificate,
    primaryCertificate,
    secondaryCertificate,
    port: Number(process.env.PORT || fileConfig.port || 8080),
    tokenTtlSeconds: Number(
      process.env.AGORA_TOKEN_TTL_SECONDS || fileConfig.tokenTtlSeconds || 3600,
    ),
  };
}

function resolveCertificate(config) {
  if (config.activeCertificate === 'secondary' && config.secondaryCertificate) {
    return config.secondaryCertificate;
  }

  if (config.primaryCertificate) {
    return config.primaryCertificate;
  }

  return config.secondaryCertificate;
}

function assertConfig(config) {
  if (!config.appId || config.appId.length !== 32) {
    throw new Error('AGORA_APP_ID is missing or invalid.');
  }

  const certificate = resolveCertificate(config);
  if (!certificate || certificate.length !== 32) {
    throw new Error(
      'No valid Agora App Certificate found. Set primary or secondary certificate in config.local.json.',
    );
  }
}

const config = resolveConfig();
assertConfig(config);

const app = express();
app.use(cors());
app.use(express.json());

app.get('/health', (_, response) => {
  response.json({
    ok: true,
    appId: config.appId,
    activeCertificate: config.activeCertificate,
    port: config.port,
  });
});

app.post('/agora/fetchAgoraRtcToken', (request, response) => {
  const {callId, channelName, agoraUid} = request.body ?? {};
  const uid = Number(agoraUid);

  if (!channelName || typeof channelName !== 'string') {
    return response.status(400).json({error: 'channelName is required.'});
  }

  if (!Number.isInteger(uid) || uid < 0) {
    return response.status(400).json({error: 'agoraUid must be a non-negative integer.'});
  }

  const privilegeExpiredTs =
    Math.floor(Date.now() / 1000) + config.tokenTtlSeconds;

  try {
    const rtcToken = RtcTokenBuilder.buildTokenWithUid(
      config.appId,
      resolveCertificate(config),
      channelName,
      uid,
      RtcRole.PUBLISHER,
      privilegeExpiredTs,
    );

    return response.json({
      callId: callId ?? '',
      channelName,
      agoraUid: uid,
      rtcToken,
      expiresAt: new Date(privilegeExpiredTs * 1000).toISOString(),
      certificateSource: config.activeCertificate,
    });
  } catch (error) {
    return response.status(500).json({
      error: 'Failed to generate Agora RTC token.',
      details: error.message,
    });
  }
});

app.listen(config.port, () => {
  console.log(
    `Agora token server running on http://127.0.0.1:${config.port} using ${config.activeCertificate} certificate.`,
  );
});
