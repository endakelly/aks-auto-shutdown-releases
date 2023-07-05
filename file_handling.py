
import json
import os
from datetime import datetime
from datetime import date

listObj = []
filepath = 'issues_list.json'
new_data = json.loads(os.environ.get('NEW_DATA', '{}'))
issue_link = json.loads(os.environ.get('ISSUE_LINK'))
print(issue_element)
print("todays date")
today = date.today()
print(today)

try:
  with open(filepath, "r") as json_file:
    listObj = json.load(json_file)
except FileNotFoundError:
  with open(filepath, "w") as json_file:
    listObj.append(new_data)
    json.dump(listObj, json_file, indent=4)
else:
  print(len(listObj))
  listObjwrite = []
  for x in range(len(listObj)):
    print("================")
    print(x)
    d = listObj[x]
    print(d)
    print(type(d))
    print(d['Skip shutdown end date'])

    end_date = datetime.strptime(d['Skip shutdown end date'], '%d-%m-%Y').date()
    print( end_date)
    print(type(end_date))
    if today < end_date:
      listObjwrite.append(d)
    print(listObjwrite) 
  if new_data:
    new_data[issue_link] = issue_link
    if new_data['Skip shutdown end date'] == "_No response_":
      new_data['Skip shutdown end date'] = today.strftime('%d-%m-%Y')
      print(new_data)
    listObjwrite.append(new_data)
  print("before write")  
  print(listObjwrite)
  with open(filepath, "w") as json_file:
    json.dump(listObjwrite, json_file, indent=4)
