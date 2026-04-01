# High Availability Topology

```
Flutter POS Clients
       |
       v
Cloudflare CDN
       |
       v
Supabase Edge API
       |
       v
Postgres Primary
   |            |
   v            v
Read Replica  Backup Replica
```

## Availability Targets

- Offline transaction continuity during internet outage
- Sync recovery after API latency spikes
- Automatic retry after device restart
- Database failover readiness with PITR

## Backup Policy

- Daily logical backup
- Point-in-time recovery enabled
- 30-day retention
