Honeydew Hospital Example
---
In this example the features of Honeydew are used to implement a simulation of a hospital (or a small part of it like the ER or a walk in medical clinic) where patients arrive, gets examined and treated. This should be a real world scenario that everyone has encountered. It is also more fun than say simulating something technical like an elevator since elevators do not get to play golf (but more about that later).


First, we start with the plan, and its basic inputs and outputs and their data types.
We are going to operate on Doctors and Patients so we need those types. We know we
are going to have input of patients arriving to get help, and that docors arrive at work.


    plan medical_clinic {
      type Doctor = Struct[{ name => String[1], speciality => String[1] }] 
      type Patient = Struct[{ name => String[1], Optional[req_speciality] => String[1] }] 
      input Doctor available_doctors
      input Patent waiting_patients
      
    }

We can now accept incoming patients and doctors (data having defined structure). Nothing actually happens yet in this empty plan. The input would just accumulate until running out of memory, so
this is not a well formed plan.

In the next step we describe that an available doctor and a waiting patient pair up so that the docor can consult with the patient. We are going to need an action for the examination, and we need a flow that describes how the pairing is done. 


    action examination(Doctor $dr, Patient $pat) {
      # the doctor d examines patient, treats patient etc.
    }
    
In this action we use the parameters `$dr` and `$pat` and we want them to be assigned to the selected available doctor and waiting patient. We do that in the flow.

    flow { [dr available_doctors,  pat waiting_patients] -> examination }

This flow expression takes input from available_doctors and alias the result to dr (this to
match the corresponding parameter name in the action as we do not want the action to use a variable name that is the same as the name of the queue (which is the default if the queue name is not aliased).

We now have a complete asyncronous program. (It does not actually do anything in the action however, but we will add to that later. Here is the complete simple first version (where we also
named the flow):

    plan medical_clinic {
      type Doctor = Struct[{ name => String[1], speciality => String[1] }] 
      type Patient = Struct[{ name => String[1], Optional[req_speciality] => String[1] }] 
      
      input Doctor available_doctors
      input Patent waiting_patients
      
      flow "doctor examines patient" {
        [dr available_doctors,  pat waiting_patients] -> examination
      }
      
      action examination(Doctor $dr, Patient $pat) {
        # the doctor d examines patient, treats patient etc.
      }

    }

> Note: The parts of the plan can be placed in any order - it still specifies the same plan.

Now lets add the requirement that "if a patient is seeking help that requires a specialist, an available doctor being a specialist in this field should select the longest waiting patient seeking help in this field".

To do that we alter the flow. Instead of specifying the selection by just giving the queues to pick from (which picks the longest waiting doctor and longest waiting patient), we now need to write
the logic that performs this matching. (For now we are ignoring the various corner cases)

    plan medical_clinic {
      type Doctor = Struct[{ name => String[1], speciality => String[1] }] 
      type Patient = Struct[{ name => String[1], Optional[req_speciality] => String[1] }] 
      
      input Doctor available_doctors
      input Patent waiting_patients
      
      flow "doctor examines patient" {
        select [dr available_doctors,  pat waiting_patients]
        order_by [
          {dr.speciality == pat.req_speciality} desc,
          pat.wait_time desc, dr.wait_time desc
        ]
      }
      
      action examination(Doctor $dr, Patient $pat) {
        # the doctor d examines patient, treats patient etc.
      }
    }
     
Before diving into what can go wrong here, lets look at what we just did.
First, the keyword 'select' was added before the selection - this is optional, but since the
logic is getting more complicated we want to spell it out to make it more readable. We then
added an order_by clause to the selection. The selection will produce a cartesian product (i.e. all combinations of available doctors and waiting patients), and all we have to do is to order them in such a fashion that if there is a match between a doctor's speciality and the required speciality then those combinations come first, secondly we order on how long the patient has been waiting, and then on doctor.

The order_by of the match requires logic, which is written within braces (otherwise a reference to
a value is assumed). We use the keyword desc because we want the result in descending order (true comes before false).

When picking values for the examination action, the picked values is simply the first combination -
or "first row" if you like.

So - what is wrong with this? If we have a positive match it will surely work, but if a doctor with a speciality arrives and there is no patient seeking such help, the first non matching patient will be picked even if they require a different speciality. Clearly this is not good.

We could try an approach of "Doctors without special field picks patients not requiring specialist help, those with specialist skills only pick those requiring this speciality". This is easy to express with two flows:

      flow "non specialist doctor examines general patient" {
        select   [dr available_doctors,  pat waiting_patients]
        where    [ ! (dr.speciality or pat.req_speciality) ]
        order_by [
          {dr.speciality == pat.req_speciality} desc,
          pat.wait_time desc, dr.wait_time desc
        ]
      }

      flow "specialist examines patient requiring one" {
        select   [dr available_doctors,  pat waiting_patients]
        where    [ dr.speciality == pat.req_speciality ]
        order_by [ pat.wait_time desc, dr.wait_time desc ]
      }

Now we have the problem that specialists will sit idle if there are no patients requiring their
specialist skills. We would also like specialists to pick general patients if there are no patients waiting requiring their skill. We achieve this adding a rule that a specialist may
pick a general patient only if there is no chance that the specialist rule will fire. This is
called an inhibitor, and is expressed as an unless selection.

     flow "specialist examines general patient unless a patient matches doctor's field" {
        unless   [dr available_doctors, pat waiting_patients]
        where    [dr.speciality == pat.req_speciality ]
        select   [dr available_doctors,  pat waiting_patients]
        where    [ ! pat.req_speciality ]
        order_by [ pat.wait_time desc, dr.wait_time desc ]
     }

This will have the effect that specialist will hang around waiting for their specialists collegues that have patients that have waited longer until it is their turn to get out the door before they get to go. This is better than having them idel for ever.

As you can see, the flows and selections are getting more complicated, and we can only imagine what happens when we add yet more rules to the mix. Can we come up with a better way to model this?

What if we instead let all doctors first consult with patients, all doctors can do this. Then, if the patient actually needs a specialist, they are deferred to one. We can specify that with 

    plan physicians_practice {
      type Document = ...
      type DrPatient = Struct[{pat => Patient, dr => Doctor, free_room => Integer}]
      input Doctor available_doctors
      input Patent waiting_patients
      output Document archive
      queue DrPatient consultation

      flow "doctor patient pair up" {   
        select   [ dr available_doctors, pat waiting_patients ]
        -> screening
       }
       
      flow "general dr/pat or matching specialist field goes to examination" {
        select [pair screening]
          where [ !pair.pat.req_speciality or pair.pat.req_specialtiy == dr.speciality ]
        -> examination { dr -> pair.dr, pat -> pair.pat }
      }
      
      flow "patient requires specialist, doctor is not one" {
        select [screening]
          where [ screening.pat.req_speciality and screening.pat.req_specialtiy != dr.speciality ]
        -> { screening.dr -> returning_doctors,
             screening.pat -> waiting_spec_patients
           }
      }
      
      flow "returning doctor that is a specialist picks matching patient" {
         select [ pat waiting_spec_patients, dr returning_doctors]
           where [ pat.speciality == dr.speciality ]
         -> examination
      }
      
      flow "returning doctor that is not a matching specialist goes back to available" {
         unless [ pat waiting_spec_patients, dr returning_doctors]
           where [ pat.speciality == dr.speciality ]
         -> { dr -> available_doctors,
              pat -> waiting_spec_patients
            }
      }
      
      flow "doctor consults with patient and produces document" {   
        select   [ dr available_doctors, pat waiting_patients ]
          order_by [ {dr.speciality == pat.speciality} desc, pat.wait_time desc, dr.wait_time desc ]
        -> consultation
        -> examination {
             dr -> available_doctors,
             pat -> drain,
             document -> archive
           }
       }
       
       queue Integer free_room {
         add_all => Integer[1,10]
       }
       flow "examination takes place in a room" {
         select free_room
         -> examination
         -> [free_room, {room => free_room}]
       }
    }


    plan physicians_practice {
      type Document = ...
      type DrPatient = Struct[{pat => Patient, dr => Doctor, free_room => Integer}]
      input Doctor available_doctors
      input Patent waiting_patients
      output Document archive
      queue DrPatient consultation
      
      flow "doctor consults with patient and produces document" {   
        select   [ dr available_doctors, pat waiting_patients ]
        order_by [ {dr.speciality == pat.speciality} desc, pat.wait_time desc, dr.wait_time desc ]
        -> consultation
        -> examination {
             dr -> available_doctors,
             pat -> drain,
             document -> archive
           }
       }
       
       queue Integer free_room {
         add_all => Integer[1,10]
       }
       flow "examination takes place in a room" {
         select free_room
         -> examination
         -> [free_room, {room => free_room}]
       }
    }
