[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-RestMethod -Method Post `
  -Uri "https://ngw.devices.sberbank.ru:9443/api/v2/oauth" `
  -Headers @{ Accept = "application/json"; RqUID = [guid]::NewGuid().ToString(); Authorization = "Basic MDFhMThkNmMtYzc3YS03MDI3LWI1MGMtODlhMGM2MjA5YWNlOjE1NjRiNjFiLWJiYzgtNDI0MS04YmQ1LThmZjhhMmJmZTIzNA==" } `
  -ContentType "application/x-www-form-urlencoded" `
  -Body "scope=GIGACHAT_API_PERS"